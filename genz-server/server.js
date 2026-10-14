const { randomInt } = require("node:crypto");
const express = require("express");
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

app.use(express.json({ limit: "16kb" }));
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
        invite_code varchar(6) NOT NULL UNIQUE,
        expires_at timestamptz NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now()
    );
    CREATE TABLE IF NOT EXISTS members (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
        name text NOT NULL,
        role text NOT NULL DEFAULT 'member',
        last_seen_at timestamptz NOT NULL DEFAULT now()
    );
    CREATE TABLE IF NOT EXISTS messages (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
        sender_id uuid NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        text text NOT NULL,
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
`;

function inputText(value, maxLength) {
    return typeof value === "string" ? value.trim().slice(0, maxLength) : "";
}

function badRequest(res, message) {
    return res.status(400).json({ error: message });
}

async function memberFor(req, res) {
    const memberId = req.get("X-Member-Id");
    const groupId = req.params.groupId;
    if (!memberId) {
        res.status(401).json({ error: "Mitgliedskennung fehlt." });
        return null;
    }
    const result = await pool.query(
        "SELECT id, group_id, name, role FROM members WHERE id = $1 AND group_id = $2",
        [memberId, groupId],
    );
    if (result.rowCount === 0) {
        res.status(403).json({ error: "Kein Zugriff auf diese Gruppe." });
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
    const name = inputText(req.body.groupName, 60);
    const memberName = inputText(req.body.memberName, 24);
    const expiresInMinutes = Number(req.body.expiresInMinutes);
    if (!name || !memberName) return badRequest(res, "Name fehlt.");
    if (
        !Number.isInteger(expiresInMinutes) ||
        expiresInMinutes < 5 ||
        expiresInMinutes > 10080
    ) {
        return badRequest(res, "Ungültige Gültigkeitsdauer.");
    }

    for (let attempt = 0; attempt < 5; attempt += 1) {
        const client = await pool.connect();
        try {
            await client.query("BEGIN");
            const inviteCode = String(randomInt(0, 1000000)).padStart(6, "0");
            const group = await client.query(
                `INSERT INTO groups(name, invite_code, expires_at)
                 VALUES ($1, $2, now() + ($3 * interval '1 minute'))
                 RETURNING id, name, invite_code, expires_at`,
                [name, inviteCode, expiresInMinutes],
            );
            const member = await client.query(
                `INSERT INTO members(group_id, name, role)
                 VALUES ($1, $2, 'organizer') RETURNING id, name, role`,
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

app.post("/api/groups/join", async (req, res) => {
    const inviteCode = inputText(req.body.inviteCode, 6);
    const memberName = inputText(req.body.memberName, 24);
    if (!/^\d{6}$/.test(inviteCode) || !memberName) {
        return badRequest(res, "Code oder Name ist ungültig.");
    }
    const client = await pool.connect();
    try {
        await client.query("BEGIN");
        const group = await client.query(
            `SELECT id, name, invite_code, expires_at FROM groups
             WHERE invite_code = $1 AND expires_at > now() FOR UPDATE`,
            [inviteCode],
        );
        if (group.rowCount === 0) {
            await client.query("ROLLBACK");
            return res.status(404).json({ error: "Code ungültig oder abgelaufen." });
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
        });
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
    const [group, members, messages, ping] = await Promise.all([
        pool.query(
            `SELECT id, name, invite_code, expires_at FROM groups
             WHERE id = $1`,
            [req.params.groupId],
        ),
        pool.query(
            `SELECT m.id, m.name, m.role,
                 (m.last_seen_at > now() - interval '60 seconds') AS online,
                 (a.member_id IS NOT NULL) AS acknowledged
             FROM members m
             LEFT JOIN pings p ON p.group_id = m.group_id
                 AND p.id = (SELECT id FROM pings WHERE group_id = m.group_id
                                         ORDER BY created_at DESC LIMIT 1)
             LEFT JOIN acknowledgements a ON a.ping_id = p.id AND a.member_id = m.id
             WHERE m.group_id = $1 ORDER BY m.name`,
            [req.params.groupId],
        ),
        pool.query(
            `SELECT messages.id, messages.text, messages.sender_id,
                 members.name AS sender_name, messages.created_at
             FROM (SELECT * FROM messages WHERE group_id = $1
                         ORDER BY created_at DESC LIMIT 100) messages
             JOIN members ON members.id = messages.sender_id
             ORDER BY messages.created_at`,
            [req.params.groupId],
        ),
        pool.query(
            `SELECT p.id, p.type, p.created_at
             FROM pings p WHERE p.group_id = $1
             ORDER BY p.created_at DESC LIMIT 1`,
            [req.params.groupId],
        ),
    ]);
    if (group.rowCount === 0) {
        return res.status(404).json({ error: "Gruppe abgelaufen oder gelöscht." });
    }
    res.json({
        group: group.rows[0],
        memberId: member.id,
        members: members.rows,
        messages: messages.rows,
        activePing: ping.rows[0] ?? null,
    });
});

app.post("/api/groups/:groupId/messages", async (req, res) => {
    const member = await memberFor(req, res);
    if (!member) return;
    const text = inputText(req.body.text, 2000);
    if (!text) return badRequest(res, "Nachricht darf nicht leer sein.");
    const result = await pool.query(
        `INSERT INTO messages(group_id, sender_id, text)
         VALUES ($1, $2, $3) RETURNING id, text, created_at`,
        [req.params.groupId, member.id, text],
    );
    res.status(201).json({ ...result.rows[0], senderName: member.name });
});

app.post("/api/groups/:groupId/pings", async (req, res) => {
    const member = await memberFor(req, res);
    if (!member) return;
    const type = inputText(req.body.type, 20);
    if (!["meetup", "help", "caution", "checkIn", "regroup"].includes(type)) {
        return badRequest(res, "Unbekannte Sicherheitsmeldung.");
    }
    const client = await pool.connect();
    try {
        await client.query("BEGIN");
        const ping = await client.query(
            `INSERT INTO pings(group_id, sender_id, type)
             VALUES ($1, $2, $3) RETURNING id, type, created_at`,
            [req.params.groupId, member.id, type],
        );
        await client.query(
            `INSERT INTO acknowledgements(ping_id, member_id) VALUES ($1, $2)`,
            [ping.rows[0].id, member.id],
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
    if (ping.rowCount === 0) return res.status(404).json({ error: "Meldung fehlt." });
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
    if (!name) return badRequest(res, "Name darf nicht leer sein.");
    const result = await pool.query(
        "UPDATE members SET name = $1 WHERE id = $2 RETURNING id, name, role",
        [name, member.id],
    );
    res.json(result.rows[0]);
});

app.use((error, _req, res, _next) => {
    console.error(error);
    res.status(500).json({ error: "Serverfehler." });
});

async function start() {
    const port = Number(process.env.PORT) || 3000;

    // 1. Server SOFORT starten, damit Render den offenen Port direkt erkennt
    app.listen(port, "0.0.0.0", () => {
        console.log(`API gestartet auf Port ${port}`);
    });

    if (!process.env.DATABASE_URL) {
        console.error("DATABASE_URL muss konfiguriert sein.");
        return;
    }

    // 2. Im Hintergrund auf die Datenbank warten
    let connected = false;
    for (let i = 1; i <= 5; i++) {
        try {
            await pool.query("SELECT 1");
            connected = true;
            console.log("Erfolgreich mit der Datenbank verbunden!");
            break;
        } catch (err) {
            console.log(`Warte auf Datenbank (Versuch ${i}/5)... Fehler:`, err.message);
            await new Promise((resolve) => setTimeout(resolve, 3000)); // 3 Sekunden warten
        }
    }

    if (!connected) {
        console.error("Konnte keine Verbindung zur Datenbank herstellen. Bitte DATABASE_URL und DATABASE_SSL prüfen.");
        return;
    }

    try {
        await pool.query(schema);
        console.log("Datenbank-Schema erfolgreich initialisiert.");
    } catch (err) {
        console.error("Fehler beim Erstellen des Tabellen-Schemas:", err);
    }
}

start();