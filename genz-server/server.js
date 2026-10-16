const { createHash, randomInt } = require("node:crypto");
const express = require("express");
const { rateLimit } = require("express-rate-limit");
const { Pool } = require("pg");

const app = express();
const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    max: 5,
    ssl:
        process.env.DATABASE_SSL === "true"
            ? { rejectUnauthorized: false }
            : undefined,
});

app.use(express.json({ limit: "1mb" }));
app.use((req, res, next) => {
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type, X-Member-Id");
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, PATCH, OPTIONS");
    if (req.method === "OPTIONS") return res.sendStatus(204);
    next();
});

const schema = `
    CREATE TABLE IF NOT EXISTS groups (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        name text NOT NULL,
        invite_code text UNIQUE,
        invite_token_hash text UNIQUE,
        expires_at timestamptz NOT NULL,
        invite_expires_at timestamptz NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now()
    );
    CREATE TABLE IF NOT EXISTS members (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
        name text NOT NULL,
        role text NOT NULL DEFAULT 'soldier',
        last_seen_at timestamptz NOT NULL DEFAULT now(),
        officer_id uuid REFERENCES members(id) ON DELETE SET NULL,
        color text,
        public_key text,
        location_lat double precision,
        location_lon double precision,
        location_updated_at timestamptz
    );
    CREATE TABLE IF NOT EXISTS messages (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
        sender_id uuid NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        encrypted_payload jsonb NOT NULL,
        channel text NOT NULL DEFAULT 'global',
        recipient_id uuid REFERENCES members(id) ON DELETE CASCADE,
        created_at timestamptz NOT NULL DEFAULT now()
    );
    CREATE TABLE IF NOT EXISTS pings (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
        sender_id uuid NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        type text NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now()
    );
    CREATE TABLE IF NOT EXISTS acknowledgements (
        ping_id uuid NOT NULL REFERENCES pings(id) ON DELETE CASCADE,
        member_id uuid NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        created_at timestamptz NOT NULL DEFAULT now(),
        PRIMARY KEY (ping_id, member_id)
    );
    CREATE INDEX IF NOT EXISTS messages_group_created_idx
        ON messages(group_id, created_at);
    CREATE INDEX IF NOT EXISTS members_group_idx ON members(group_id);
    CREATE INDEX IF NOT EXISTS pings_group_created_idx
        ON pings(group_id, created_at DESC);
    ALTER TABLE members ADD COLUMN IF NOT EXISTS officer_id uuid
        REFERENCES members(id) ON DELETE SET NULL;
    ALTER TABLE members ADD COLUMN IF NOT EXISTS color text;
    ALTER TABLE members ADD COLUMN IF NOT EXISTS public_key text;
    ALTER TABLE members ADD COLUMN IF NOT EXISTS location_lat double precision;
    ALTER TABLE members ADD COLUMN IF NOT EXISTS location_lon double precision;
    ALTER TABLE members ADD COLUMN IF NOT EXISTS location_updated_at timestamptz;
    ALTER TABLE groups ADD COLUMN IF NOT EXISTS invite_expires_at timestamptz;
    ALTER TABLE groups ALTER COLUMN invite_code TYPE text;
    ALTER TABLE groups ALTER COLUMN invite_code DROP NOT NULL;
    ALTER TABLE groups ADD COLUMN IF NOT EXISTS invite_token_hash text;
    CREATE UNIQUE INDEX IF NOT EXISTS groups_invite_token_hash_idx
        ON groups(invite_token_hash) WHERE invite_token_hash IS NOT NULL;
    UPDATE groups SET invite_expires_at = LEAST(now() + interval '15 minutes', expires_at)
        WHERE invite_expires_at IS NULL;
    ALTER TABLE groups ALTER COLUMN invite_expires_at SET NOT NULL;
    UPDATE members SET role = 'general' WHERE role = 'organizer';
    UPDATE members SET role = 'soldier' WHERE role = 'member';
    UPDATE members SET color = '#FF3B30' WHERE role = 'general' AND color IS NULL;
    ALTER TABLE members ALTER COLUMN role SET DEFAULT 'soldier';
    UPDATE members SET location_lat = NULL, location_lon = NULL,
        location_updated_at = NULL
        WHERE location_updated_at < now() - interval '2 minutes';
    ALTER TABLE messages ADD COLUMN IF NOT EXISTS encrypted_payload jsonb;
    ALTER TABLE messages ADD COLUMN IF NOT EXISTS channel text NOT NULL DEFAULT 'global';
    ALTER TABLE messages ADD COLUMN IF NOT EXISTS recipient_id uuid
        REFERENCES members(id) ON DELETE CASCADE;
    DELETE FROM messages WHERE encrypted_payload IS NULL;
    ALTER TABLE messages DROP COLUMN IF EXISTS text;
    ALTER TABLE messages ALTER COLUMN encrypted_payload SET NOT NULL;
    CREATE INDEX IF NOT EXISTS members_location_updated_idx
        ON members(location_updated_at);
`;

function randomOfficerColor() {
    return `#${randomInt(0x1000000).toString(16).padStart(6, "0").toUpperCase()}`;
}

function inputText(value, maxLength) {
    return typeof value === "string" ? value.trim().slice(0, maxLength) : "";
}

function badRequest(res, message) {
    return res.status(400).json({ error: message });
}

function canUseChannel(role, channel) {
    if (channel === "global") return true;
    if (channel === "command") return role === "general" || role === "officer";
    if (channel === "briefing") return role === "officer" || role === "soldier";
    return false;
}

function hashInviteToken(token) {
    return createHash("sha256").update(token).digest("hex");
}

function newInviteCode() {
    return String(randomInt(10_000_000, 100_000_000));
}

async function memberFor(req, res) {
    const memberId = req.get("X-Member-Id");
    const groupId = req.params.groupId;
    if (!memberId) {
        res.status(401).json({ error: "Member ID is required." });
        return null;
    }
    const result = await pool.query(
        "SELECT id, group_id, name, role FROM members WHERE id = $1 AND group_id = $2",
        [memberId, groupId],
    );
    if (result.rowCount === 0) {
        res.status(403).json({ error: "You do not have access to this group." });
        return null;
    }
    return result.rows[0];
}

app.get("/", (_req, res) => {
    res.json({ service: "Project Cat and Mouse API", status: "ok" });
});

app.get("/health", async (_req, res) => {
    await pool.query("SELECT 1");
    res.json({ status: "ok" });
});

app.post("/api/groups", async (req, res) => {
    const existingMemberId = req.get("X-Member-Id");
    if (existingMemberId) {
        const existingMember = await pool.query(
            "SELECT role FROM members WHERE id = $1",
            [existingMemberId],
        );
        if (existingMember.rowCount === 0) {
            return res.status(403).json({ error: "Invalid member ID." });
        }
        if (existingMember.rows[0].role !== "general") {
            return res.status(403).json({
                error: "Only the General can create another group.",
            });
        }
    }
    const name = inputText(req.body.groupName, 60);
    const memberName = inputText(req.body.memberName, 24);
    const expiresInMinutes = Number(req.body.expiresInMinutes);
    if (!name || !memberName) return badRequest(res, "A name is required.");
    if (
        !Number.isInteger(expiresInMinutes) ||
        expiresInMinutes < 5 ||
        expiresInMinutes > 10080
    ) {
        return badRequest(res, "Invalid expiration duration.");
    }

    for (let attempt = 0; attempt < 5; attempt += 1) {
        const client = await pool.connect();
        try {
            await client.query("BEGIN");
            const inviteCode = newInviteCode();
            const group = await client.query(
                `INSERT INTO groups(name, invite_code, invite_token_hash,
                                    expires_at, invite_expires_at)
                 VALUES ($1, $2, NULL, now() + ($3 * interval '1 minute'),
                     now() + ($3 * interval '1 minute'))
                 RETURNING id, name, invite_code, invite_expires_at, expires_at`,
                [name, inviteCode, expiresInMinutes],
            );
            const member = await client.query(
                `INSERT INTO members(group_id, name, role)
                 VALUES ($1, $2, 'general') RETURNING id, name, role`,
                [group.rows[0].id, memberName],
            );
            await client.query("COMMIT");
            return res.status(201).json({
                group: group.rows[0],
                member: member.rows[0],
            });
        } catch (error) {
            await client.query("ROLLBACK");
            if (error.code !== "23505" || attempt === 4) throw error;
        } finally {
            client.release();
        }
    }
});

app.post(
    "/api/groups/join",
    rateLimit({
        windowMs: 15 * 60 * 1000,
        limit: 20,
        standardHeaders: "draft-7",
        legacyHeaders: false,
    }),
    async (req, res) => {
    const inviteCode = inputText(req.body.inviteCode, 128);
    const memberName = inputText(req.body.memberName, 24);
    const isNumericCode = /^\d{8}$/.test(inviteCode) || /^\d{6}$/.test(inviteCode);
    const isSecureToken = /^[0-9a-f]{64}$/.test(inviteCode);
    if ((!isNumericCode && !isSecureToken) || !memberName) {
        return badRequest(res, "The invite code or name is invalid.");
    }
    const tokenHash = isSecureToken ? hashInviteToken(inviteCode) : null;
    const client = await pool.connect();
    try {
        await client.query("BEGIN");
        const group = await client.query(
            `SELECT id, name, invite_expires_at, expires_at FROM groups
             WHERE (($2::text IS NULL AND invite_code = $1)
                    OR invite_token_hash = $2)
               AND expires_at > now()
               AND invite_expires_at > now() FOR UPDATE`,
            [inviteCode, tokenHash],
        );
        if (group.rowCount === 0) {
            await client.query("ROLLBACK");
            return res.status(404).json({ error: "Invite code is invalid or expired." });
        }
        const member = await client.query(
            `INSERT INTO members(group_id, name)
             VALUES ($1, $2) RETURNING id, name, role`,
            [group.rows[0].id, memberName],
        );
        await client.query("COMMIT");
        return res.status(201).json({
            group: group.rows[0],
            member: member.rows[0],
            },
        );
    } catch (error) {
        await client.query("ROLLBACK");
        throw error;
    } finally {
        client.release();
    }
});

app.get("/api/groups/:groupId", async (req, res) => {
    const member = await memberFor(req, res);
    if (!member) return;
    await pool.query("UPDATE members SET last_seen_at = now() WHERE id = $1", [
        member.id,
    ]);
    let refreshedInviteCode;
    if (member.role === "general") {
        for (let attempt = 0; attempt < 5; attempt += 1) {
            const inviteCode = newInviteCode();
            try {
                const rotated = await pool.query(
                    `UPDATE groups SET invite_code = $1, invite_token_hash = NULL,
                        invite_expires_at = expires_at
                     WHERE id = $2 AND expires_at > now()
                       AND (invite_code IS NULL OR invite_code !~ '^[0-9]{8}$')`,
                    [inviteCode, req.params.groupId],
                );
                if (rotated.rowCount > 0) refreshedInviteCode = inviteCode;
                break;
            } catch (error) {
                if (error.code !== "23505" || attempt === 4) throw error;
            }
        }
    }
    const [group, messages] = await Promise.all([
        pool.query(
            `SELECT id, name, invite_code, invite_expires_at, expires_at FROM groups
             WHERE id = $1`,
            [req.params.groupId],
        ),
        pool.query(
            `SELECT messages.id, messages.encrypted_payload, messages.sender_id,
                 messages.channel, messages.recipient_id,
                 members.name AS sender_name, messages.created_at
             FROM (SELECT messages.* FROM messages
                         JOIN members AS current_member ON current_member.id = $2
                         WHERE messages.group_id = $1 AND (
                             messages.channel = 'global'
                             OR (messages.channel = 'command'
                                 AND current_member.role IN ('general', 'officer'))
                             OR (messages.channel = 'briefing'
                                 AND current_member.role IN ('officer', 'soldier'))
                             OR (messages.channel = 'direct'
                                 AND (messages.sender_id = $2 OR messages.recipient_id = $2))
                         )
                         ORDER BY messages.created_at DESC LIMIT 100) messages
             JOIN members ON members.id = messages.sender_id
             ORDER BY messages.created_at`,
            [req.params.groupId, member.id],
        ),
    ]);
    if (group.rowCount === 0) {
        return res.status(404).json({ error: "Group has expired or was deleted." });
    }
    const ping = await pool.query(
        `SELECT p.id, p.type, p.created_at, sender.name AS sender_name,
             COUNT(a.member_id)::int AS acknowledged_count,
             (SELECT COUNT(*)::int FROM members WHERE group_id = $1) AS member_count
         FROM pings p
         JOIN members sender ON sender.id = p.sender_id AND sender.group_id = p.group_id
         LEFT JOIN acknowledgements a ON a.ping_id = p.id
         WHERE p.group_id = $1
         GROUP BY p.id, sender.name
         HAVING p.created_at > now() - interval '10 minutes'
            AND (p.created_at > now() - interval '3 minutes'
                 OR COUNT(a.member_id) < CEIL(
                     (SELECT COUNT(*) FROM members WHERE group_id = $1) * 0.8
                 ))
         ORDER BY p.created_at DESC LIMIT 1`,
        [req.params.groupId],
    );
    const activePing = ping.rows[0] ?? null;
    const members = await pool.query(
        `SELECT m.id, m.name, m.role, m.officer_id, m.color, m.public_key,
             (m.last_seen_at > now() - interval '60 seconds') AS online,
             CASE WHEN m.location_updated_at > now() - interval '2 minutes'
                  THEN m.location_lat ELSE NULL END AS latitude,
             CASE WHEN m.location_updated_at > now() - interval '2 minutes'
                  THEN m.location_lon ELSE NULL END AS longitude,
             CASE WHEN m.location_updated_at > now() - interval '2 minutes'
                  THEN m.location_updated_at ELSE NULL END AS location_updated_at,
             (a.member_id IS NOT NULL) AS acknowledged
         FROM members m
         LEFT JOIN acknowledgements a
             ON a.ping_id = $2 AND a.member_id = m.id
         WHERE m.group_id = $1 ORDER BY m.name`,
        [req.params.groupId, activePing?.id ?? null],
    );
    res.json({
        group: {
            ...group.rows[0],
            invite_code: member.role === "general"
                ? refreshedInviteCode ?? group.rows[0].invite_code
                : null,
            invite_expires_at:
                member.role === "general" ? group.rows[0].invite_expires_at : null,
        },
        memberId: member.id,
        members: members.rows,
        messages: messages.rows,
        activePing,
    });
});

app.post("/api/groups/:groupId/messages", async (req, res) => {
    const member = await memberFor(req, res);
    if (!member) return;
    const payload = req.body.encryptedPayload;
    const channel = inputText(req.body.channel, 20);
    const recipientId = req.body.recipientId ?? null;
    if (channel === "direct") {
        if (typeof recipientId !== "string" || recipientId === member.id) {
            return badRequest(res, "A direct message needs a valid recipient.");
        }
    } else if (!canUseChannel(member.role, channel) || recipientId !== null) {
        return res.status(403).json({ error: "You cannot send messages to this chat." });
    }
    const recipients = payload?.recipients;
    if (
        payload?.version !== 1 ||
        recipients === null ||
        typeof recipients !== "object" ||
        Array.isArray(recipients) ||
        Buffer.byteLength(JSON.stringify(payload), "utf8") > 900_000
    ) {
        return badRequest(res, "Encrypted message is invalid.");
    }
    const groupMembers = channel === "direct"
        ? await pool.query(
              `SELECT id, public_key FROM members
               WHERE group_id = $1 AND id IN ($2, $3)`,
              [req.params.groupId, member.id, recipientId],
          )
        : await pool.query(
              `SELECT id, public_key, role FROM members WHERE group_id = $1`,
              [req.params.groupId],
          );
    if (channel === "direct" && groupMembers.rowCount !== 2) {
        return badRequest(res, "The direct-message recipient is not in this group.");
    }
    if (
        channel !== "direct" &&
        groupMembers.rows.some((recipient) => !canUseChannel(recipient.role, channel))
    ) {
        return badRequest(res, "The selected chat has an invalid audience.");
    }
    if (
        groupMembers.rows.some(
            (recipient) =>
                !recipient.public_key ||
                !Object.hasOwn(recipients, recipient.id) ||
                !isValidEnvelope(recipients[recipient.id]),
        ) ||
        Object.keys(recipients).length !== groupMembers.rowCount
    ) {
        return res.status(409).json({
            error: "Chat keys are missing for group members. Refresh the group and try again.",
        });
    }
    const result = await pool.query(
        `INSERT INTO messages(group_id, sender_id, encrypted_payload, channel, recipient_id)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id, encrypted_payload, channel, recipient_id, created_at`,
        [req.params.groupId, member.id, payload, channel, recipientId],
    );
    res.status(201).json({ ...result.rows[0], senderName: member.name });
});

function isValidEnvelope(envelope) {
    return (
        envelope !== null &&
        typeof envelope === "object" &&
        typeof envelope.ephemeralKey === "string" &&
        typeof envelope.salt === "string" &&
        typeof envelope.nonce === "string" &&
        typeof envelope.cipherText === "string" &&
        typeof envelope.mac === "string"
    );
}

app.patch("/api/groups/:groupId/members/me/key", async (req, res) => {
    const member = await memberFor(req, res);
    if (!member) return;
    const publicKey = req.body.publicKey;
    if (
        typeof publicKey !== "string" ||
        !/^[A-Za-z0-9+/]+={0,2}$/.test(publicKey) ||
        Buffer.from(publicKey, "base64").length !== 32
    ) {
        return badRequest(res, "Public chat key is invalid.");
    }
    const result = await pool.query(
        `UPDATE members SET public_key = $1
         WHERE id = $2 AND (public_key IS NULL OR public_key = $1)
         RETURNING public_key`,
        [publicKey, member.id],
    );
    if (result.rowCount === 0) {
        return res.status(409).json({
            error: "A different chat key is already registered for this device.",
        });
    }
    res.json({ publicKey: result.rows[0].public_key });
});

app.patch("/api/groups/:groupId/location", async (req, res) => {
    const member = await memberFor(req, res);
    if (!member) return;
    if (req.body.enabled === false) {
        await pool.query(
            `UPDATE members SET location_lat = NULL, location_lon = NULL,
             location_updated_at = NULL WHERE id = $1`,
            [member.id],
        );
        return res.sendStatus(204);
    }
    const { latitude, longitude } = req.body;
    if (
        typeof latitude !== "number" ||
        typeof longitude !== "number" ||
        !Number.isFinite(latitude) ||
        !Number.isFinite(longitude) ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180
    ) {
        return badRequest(res, "Location coordinates are invalid.");
    }
    await pool.query(
        `UPDATE members SET location_lat = $1, location_lon = $2,
         location_updated_at = now() WHERE id = $3`,
        [latitude, longitude, member.id],
    );
    res.sendStatus(204);
});

app.post("/api/groups/:groupId/members/:memberId/promote", async (req, res) => {
    const member = await memberFor(req, res);
    if (!member) return;
    if (member.role !== "general") {
        return res.status(403).json({ error: "Only the General can promote members to officer." });
    }
    const result = await pool.query(
        `UPDATE members SET role = 'officer', officer_id = NULL, color = $1
         WHERE id = $2 AND group_id = $3 AND role = 'soldier'
         RETURNING id, name, role, officer_id, color`,
        [randomOfficerColor(), req.params.memberId, req.params.groupId],
    );
    if (result.rowCount === 0) {
        return res.status(404).json({ error: "Soldier not found." });
    }
    res.json(result.rows[0]);
});

app.post("/api/groups/:groupId/members/:memberId/kick", async (req, res) => {
    const member = await memberFor(req, res);
    if (!member) return;
    if (member.role !== "general") {
        return res.status(403).json({ error: "Only the General can remove members." });
    }
    const result = await pool.query(
        `DELETE FROM members
         WHERE id = $1 AND group_id = $2 AND role <> 'general'
         RETURNING id`,
        [req.params.memberId, req.params.groupId],
    );
    if (result.rowCount === 0) {
        return res.status(404).json({ error: "Member not found or cannot be removed." });
    }
    res.sendStatus(204);
});

app.post("/api/groups/:groupId/leave", async (req, res) => {
    const member = await memberFor(req, res);
    if (!member) return;
    const client = await pool.connect();
    try {
        await client.query("BEGIN");
        const group = await client.query(
            "SELECT id FROM groups WHERE id = $1 FOR UPDATE",
            [req.params.groupId],
        );
        if (group.rowCount === 0) {
            await client.query("ROLLBACK");
            return res.status(404).json({ error: "Group not found." });
        }
        await client.query("DELETE FROM members WHERE id = $1", [member.id]);
        if (member.role === "general") {
            const nextGeneral = await client.query(
                `SELECT id FROM members WHERE group_id = $1
                 ORDER BY last_seen_at, id LIMIT 1`,
                [req.params.groupId],
            );
            if (nextGeneral.rowCount === 0) {
                await client.query("DELETE FROM groups WHERE id = $1", [req.params.groupId]);
            } else {
                await client.query(
                    "UPDATE members SET role = 'general' WHERE id = $1",
                    [nextGeneral.rows[0].id],
                );
            }
        }
        await client.query("COMMIT");
        return res.sendStatus(204);
    } catch (error) {
        await client.query("ROLLBACK");
        throw error;
    } finally {
        client.release();
    }
});

app.post("/api/groups/:groupId/invite/rotate", async (req, res) => {
    const member = await memberFor(req, res);
    if (!member) return;
    if (member.role !== "general") {
        return res.status(403).json({ error: "Only the General can rotate the invite." });
    }
    for (let attempt = 0; attempt < 5; attempt += 1) {
        const inviteCode = newInviteCode();
        try {
            const result = await pool.query(
                `UPDATE groups SET invite_code = $1, invite_token_hash = NULL,
                    invite_expires_at = expires_at
                 WHERE id = $2 AND expires_at > now()
                 RETURNING invite_expires_at`,
                [inviteCode, req.params.groupId],
            );
            if (result.rowCount === 0) {
                return res.status(404).json({ error: "Group has expired." });
            }
            return res.json({ ...result.rows[0], invite_code: inviteCode });
        } catch (error) {
            if (error.code !== "23505" || attempt === 4) throw error;
        }
    }
});

app.patch("/api/groups/:groupId/members/me/officer", async (req, res) => {
    const member = await memberFor(req, res);
    if (!member) return;
    if (member.role !== "soldier") {
        return res.status(403).json({ error: "Only soldiers can join an officer group." });
    }
    const officerId = inputText(req.body.officerId, 36);
    const officer = await pool.query(
        "SELECT id FROM members WHERE id = $1 AND group_id = $2 AND role = 'officer'",
        [officerId, req.params.groupId],
    );
    if (officer.rowCount === 0) {
        return badRequest(res, "Officer not found.");
    }
    await pool.query("UPDATE members SET officer_id = $1 WHERE id = $2", [
        officerId,
        member.id,
    ]);
    res.sendStatus(204);
});

app.post("/api/groups/:groupId/pings", async (req, res) => {
    const member = await memberFor(req, res);
    if (!member) return;
    const type = inputText(req.body.type, 20);
    if (!["meetup", "help", "caution", "checkIn", "regroup"].includes(type)) {
        return badRequest(res, "Unknown safety alert.");
    }
    const client = await pool.connect();
    try {
        await client.query("BEGIN");
        const ping = await client.query(
            `INSERT INTO pings(group_id, sender_id, type)
             VALUES ($1, $2, $3) RETURNING id, type, created_at`,
            [req.params.groupId, member.id, type],
        );
        await client.query("COMMIT");
        return res.status(201).json(ping.rows[0]);
    } catch (error) {
        await client.query("ROLLBACK");
        throw error;
    } finally {
        client.release();
    }
});

app.post("/api/groups/:groupId/pings/:pingId/ack", async (req, res) => {
    const member = await memberFor(req, res);
    if (!member) return;
    const ping = await pool.query(
        "SELECT id FROM pings WHERE id = $1 AND group_id = $2",
        [req.params.pingId, req.params.groupId],
    );
    if (ping.rowCount === 0) return res.status(404).json({ error: "Alert not found." });
    await pool.query(
        `INSERT INTO acknowledgements(ping_id, member_id) VALUES ($1, $2)
         ON CONFLICT DO NOTHING`,
        [req.params.pingId, member.id],
    );
    res.sendStatus(204);
});

app.patch("/api/groups/:groupId/members/me", async (req, res) => {
    const member = await memberFor(req, res);
    if (!member) return;
    const name = inputText(req.body.name, 24);
    if (!name) return badRequest(res, "Name cannot be empty.");
    const result = await pool.query(
        "UPDATE members SET name = $1 WHERE id = $2 RETURNING id, name, role, officer_id, color",
        [name, member.id],
    );
    res.json(result.rows[0]);
});

app.use((error, _req, res, _next) => {
    console.error(error);
    res.status(500).json({ error: "Server error." });
});

async function start() {
    const port = Number(process.env.PORT) || 3000;

    // Start the server immediately so the hosting platform sees the open port.
    app.listen(port, "0.0.0.0", () => {
        console.log(`API listening on port ${port}`);
    });

    if (!process.env.DATABASE_URL) {
        console.error("DATABASE_URL must be configured.");
        return;
    }

    // Wait for the database after the server starts.
    let connected = false;
    for (let i = 1; i <= 5; i++) {
        try {
            await pool.query("SELECT 1");
            connected = true;
            console.log("Connected to the database.");
            break;
        } catch (err) {
            console.log(`Waiting for database (attempt ${i}/5)... Error:`, err.message);
            await new Promise((resolve) => setTimeout(resolve, 3000));
        }
    }

    if (!connected) {
        console.error("Could not connect to the database. Check DATABASE_URL and DATABASE_SSL.");
        return;
    }

    try {
        await pool.query(schema);
        console.log("Database schema initialized.");
        const locationCleanup = setInterval(() => {
            pool.query(
                `UPDATE members SET location_lat = NULL, location_lon = NULL,
                 location_updated_at = NULL
                 WHERE location_updated_at < now() - interval '2 minutes'`,
            ).catch((error) => {
                console.error("Could not clear stale locations:", error);
            });
        }, 30_000);
        locationCleanup.unref();
        const pingCleanup = setInterval(() => {
            pool.query(
                `DELETE FROM pings p
                 WHERE p.created_at <= now() - interval '10 minutes'
                    OR (p.created_at <= now() - interval '3 minutes'
                        AND (SELECT COUNT(*) FROM acknowledgements a
                             WHERE a.ping_id = p.id) >= CEIL(
                                (SELECT COUNT(*) FROM members m
                                 WHERE m.group_id = p.group_id) * 0.8
                            ))`,
            ).catch((error) => {
                console.error("Could not clear expired pings:", error);
            });
        }, 30_000);
        pingCleanup.unref();
    } catch (err) {
        console.error("Could not initialize the database schema:", err);
    }
}

start();