using Godot;
using Microsoft.Data.Sqlite;
using System;
using System.IO;
using GArray = Godot.Collections.Array;
using GDictionary = Godot.Collections.Dictionary;

public partial class LocalRankingStore : RefCounted
{
    private SqliteConnection connection;
    private string error = "";
    public string get_error() => error;
    public bool open_store(string filename)
    {
        try
        {
            connection?.Dispose();
            Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(filename))!);
            connection = new SqliteConnection(new SqliteConnectionStringBuilder {
                DataSource = filename, Mode = SqliteOpenMode.ReadWriteCreate,
                DefaultTimeout = 3, Pooling = false
            }.ToString());
            connection.Open();
            using (var version = connection.CreateCommand()) {
                version.CommandText = "PRAGMA user_version";
                if (Convert.ToInt32(version.ExecuteScalar()) > 1)
                    throw new InvalidOperationException("This ranking database belongs to a newer game version.");
            }
            using var command = connection.CreateCommand();
            command.CommandText = @"
PRAGMA foreign_keys=ON;
PRAGMA journal_mode=WAL;
CREATE TABLE IF NOT EXISTS sessions (
 id TEXT PRIMARY KEY, track_id TEXT NOT NULL, mode INTEGER NOT NULL,
 ruleset TEXT NOT NULL, ended_utc TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS results (
 session_id TEXT NOT NULL REFERENCES sessions(id), profile_id TEXT NOT NULL,
 player_name TEXT NOT NULL, driver_id TEXT NOT NULL, vehicle_id TEXT NOT NULL,
 class_id TEXT NOT NULL, place INTEGER NOT NULL, race_ms INTEGER NOT NULL,
 lap_ms INTEGER NOT NULL, PRIMARY KEY(session_id, profile_id));
CREATE INDEX IF NOT EXISTS result_times ON results(class_id,race_ms,lap_ms);
CREATE TABLE IF NOT EXISTS session_courses (
 session_id TEXT PRIMARY KEY REFERENCES sessions(id), revision INTEGER NOT NULL);
INSERT OR IGNORE INTO session_courses SELECT id,1 FROM sessions;
PRAGMA user_version=1;";
            command.ExecuteNonQuery();
            error = "";
            return true;
        }
        catch (Exception ex) { error = ex.Message; connection?.Dispose(); connection = null; return false; }
    }
    public int save_session(string sessionId, int mode, GArray rows, bool modified, bool diagnostic)
        => save_session_for_track(sessionId, mode, rows, modified, diagnostic, "astra_coast", 1);

    public int save_session_for_track(string sessionId, int mode, GArray rows, bool modified, bool diagnostic, string trackId, int courseRevision, string ruleset = "balanced_v1")
    {
        if (modified || diagnostic) return 0;
        if (string.IsNullOrWhiteSpace(trackId) || courseRevision < 1) { error = "Invalid course identity."; return -1; }
        if (connection == null) { error = "Ranking database is unavailable."; return -1; }
        try
        {
            using var transaction = connection.BeginTransaction();
            using (var session = connection.CreateCommand())
            {
                session.Transaction = transaction;
                session.CommandText = "INSERT OR IGNORE INTO sessions VALUES ($id,$track,$mode,$rules,$ended)";
                session.Parameters.AddWithValue("$id",sessionId);
                session.Parameters.AddWithValue("$track",trackId);
                session.Parameters.AddWithValue("$mode",mode);
                session.Parameters.AddWithValue("$rules",ruleset);
                session.Parameters.AddWithValue("$ended",DateTime.UtcNow.ToString("O"));
                session.ExecuteNonQuery();
            }
            using (var course = connection.CreateCommand()) {
                course.Transaction = transaction;
                course.CommandText = "INSERT OR IGNORE INTO session_courses VALUES ($id,$revision)";
                course.Parameters.AddWithValue("$id",sessionId);
                course.Parameters.AddWithValue("$revision",courseRevision);
                course.ExecuteNonQuery();
            }
            int count = 0;
            foreach (Variant item in rows)
            {
                var row = item.AsGodotDictionary();
                if (!row["finished"].AsBool() || row["retired"].AsBool() || row["next_gate"].AsInt32() < 25) continue;
                double race = row["race_time"].AsDouble(), lap = row["best_lap"].AsDouble();
                if (!double.IsFinite(race) || !double.IsFinite(lap) || race <= 0 || lap <= 0 || lap >= 99999) continue;
                using var insert = connection.CreateCommand();
                insert.Transaction = transaction;
                insert.CommandText = @"INSERT OR IGNORE INTO results VALUES
($session,$profile,$name,$driver,$vehicle,$class,$place,$race,$lap)";
                insert.Parameters.AddWithValue("$session",sessionId);
                insert.Parameters.AddWithValue("$profile",row["profile_id"].AsString());
                insert.Parameters.AddWithValue("$name",row["name"].AsString());
                insert.Parameters.AddWithValue("$driver",row["driver"].AsString());
                insert.Parameters.AddWithValue("$vehicle",row["vehicle"].AsString());
                insert.Parameters.AddWithValue("$class",row["class_id"].AsString());
                insert.Parameters.AddWithValue("$place",row["place"].AsInt32());
                insert.Parameters.AddWithValue("$race",(long)Math.Round(race*1000,MidpointRounding.AwayFromZero));
                insert.Parameters.AddWithValue("$lap",(long)Math.Round(lap*1000,MidpointRounding.AwayFromZero));
                count += insert.ExecuteNonQuery();
            }
            transaction.Commit();
            error = "";
            return count;
        }
        catch (Exception ex) { error = ex.Message; return -1; }
    }
    public GArray best_times(int mode, string performanceClass, string vehicle, bool laps)
        => best_times_for_track(mode, performanceClass, vehicle, laps, "astra_coast", 1);

    public GArray best_times_for_track(int mode, string performanceClass, string vehicle, bool laps, string trackId, int courseRevision, string ruleset = "balanced_v1")
    {
        var result = new GArray();
        if (connection == null) { error = "Ranking database is unavailable."; return result; }
        try
        {
            string metric = laps ? "lap_ms" : "race_ms";
            using var command = connection.CreateCommand();
            command.CommandText = $@"SELECT player_name,driver_id,vehicle_id,race_ms,lap_ms,profile_id FROM (
SELECT r.*,s.ended_utc, ROW_NUMBER() OVER(PARTITION BY r.profile_id ORDER BY r.{metric},s.ended_utc,r.session_id) AS number
FROM results r JOIN sessions s ON r.session_id=s.id
LEFT JOIN session_courses c ON c.session_id=s.id
WHERE s.track_id=$track AND COALESCE(c.revision,1)=$revision AND s.ruleset=$rules AND s.mode=$mode
AND r.class_id=$class AND ($vehicle='' OR r.vehicle_id=$vehicle))
WHERE number=1 ORDER BY {metric},ended_utc,profile_id LIMIT 100";
            command.Parameters.AddWithValue("$mode",mode);
            command.Parameters.AddWithValue("$rules",ruleset);
            command.Parameters.AddWithValue("$track",trackId);
            command.Parameters.AddWithValue("$revision",courseRevision);
            command.Parameters.AddWithValue("$class",performanceClass);
            command.Parameters.AddWithValue("$vehicle",vehicle);
            using var reader = command.ExecuteReader();
            while (reader.Read()) result.Add(new GDictionary {
                ["name"]=reader.GetString(0), ["driver"]=reader.GetString(1), ["vehicle"]=reader.GetString(2),
                ["race_ms"]=reader.GetInt64(3), ["lap_ms"]=reader.GetInt64(4), ["profile_id"]=reader.GetString(5)
            });
            error = "";
        }
        catch (Exception ex) { error = ex.Message; }
        return result;
    }
    public void close_store() { connection?.Dispose(); connection = null; }
}
