/* -*- Mode: C; indent-tabs-mode: t; c-basic-offset: 4; tab-width: 4 -*- */
/*
 * Copyright (c) 2010 Jordi Puigdellívol <jordi@gloobus.net>
 *
 * This library is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License
 * version 3.0 as published by the Free Software Foundation.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License version 3.0 for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library. If not, see
 * <http://www.gnu.org/licenses/>.
 *
 * Authors: Jordi Puigdellívol <jordi@gloobus.net>
 *          ammonkey <am.monkeyd@gmail.com>
 *

 Marlin Tagging system

//Dependences
libsqlite3-dev

//To create de table
create table tags (uri TEXT, color INT, tags TEXT);

//To compile this sample
valac --pkg sqlite3 -o sqlitesample SqliteSample.vala
valac --pkg sqlite3 --pkg gio-2.0 -o sqlitesample marlin_tagging.vala && ./sqlitesample

*/

[DBus (name = "io.elementary.files4.db")]
public class MarlinTags : Object {
    private const string CMD = "INSERT OR REPLACE INTO tags (uri, content_type, color, modified_time, dir) " +
                               "VALUES ('%s', '%s', %s, %s, '%s');\n";
    protected static Sqlite.Database db;

    public MarlinTags () {
        try {
            open_marlin_db ();
        } catch (GLib.Error e) {
            critical ("Unable to open color tag database: %s", e.message);
        }
    }

    protected static void fatal (string op, int res) {
        error ("%s: [%d] %s", op, res, db.errmsg ());
    }

    private static int show_table_callback (int n_columns, string[] values, string[] column_names) {
        for (int i = 0; i < n_columns; i++) {
            stdout.printf ("%s = %s\n", column_names[i], values[i]);
        }

        stdout.printf ("\n");

        return 0;
    }

    public bool open_marlin_db () throws GLib.DBusError, GLib.IOError {
        File home_dir = File.new_for_path (Environment.get_home_dir ());
        File data_dir = home_dir.get_child (".config").get_child ("marlin");

        try {
            if (!data_dir.query_exists (null)) {
                data_dir.make_directory_with_parents (null);
            }
        } catch (Error err) {
            throw new GLib.IOError.FAILED ("Unable to create data directory %s: %s", data_dir.get_path (), err.message);
        }

        string marlin_db_path = data_dir.get_child ("marlin.db").get_path ();
        //The database must exists, add here the full path
        message ("Database path: %s \n", marlin_db_path);
        open_db (marlin_db_path);

        return true;
    }

    private bool open_db (string dbpath) {
        int rc = Sqlite.Database.open_v2 (dbpath, out db, Sqlite.OPEN_READWRITE | Sqlite.OPEN_CREATE, null);

        if (rc != Sqlite.OK) {
            warning ("Can't open database: %d, %s\n", rc, db.errmsg ());
            return false;
        }

        // disable synchronized commits for performance reasons ... this is not vital
        rc = db.exec ("PRAGMA synchronous=OFF");

        if (rc != Sqlite.OK) {
            warning ("Unable to disable synchronous mode %d, %s\n", rc, db.errmsg ());
        }

        Sqlite.Statement stmt;
        int res = db.prepare_v2 ("CREATE TABLE IF NOT EXISTS tags ("
                                + "id INTEGER PRIMARY KEY, "
                                + "uri TEXT UNIQUE NOT NULL, "
                                + "color INTEGER DEFAULT 0, "
                                + "tags TEXT NULL, "
                                + "content_type TEXT, "
                                + "modified_time INTEGER DEFAULT 0, "
                                + "dir TEXT "
                                + ")", -1, out stmt);

        assert (res == Sqlite.OK);
        res = stmt.step ();

        if (res != Sqlite.DONE) {
            fatal ("create tags table", res);
        }

        /* TODO check result of the last sql command */
        upgrade_database ();

        return true;
    }

    public async bool record_uris (Variant[] locations) throws GLib.DBusError, GLib.IOError {
        var sql = "";

        foreach (var location_variant in locations) {
            VariantIter iter = location_variant.iterator ();

            var raw_uri = iter.next_value ().get_string ();
            var uri = escape (raw_uri);
            var directory = escape (Files.FileUtils.get_parent_path_from_path (raw_uri));
            var content_type = iter.next_value ().get_string ();
            var modified_time = iter.next_value ().get_string ();
            var color = iter.next_value ().get_string ();
            sql += CMD.printf (uri, content_type, color, modified_time, directory);
        }

        int rc = db.exec (sql, null, null);

        if (rc != Sqlite.OK) {
            warning ("[record_uri: SQL error]  %d, %s, %s\n", rc, sql, db.errmsg ());
            return false;
        }

        return true;
    }

    private string escape (string input) {
        return Files.FileUtils.escape_uri (input, true, false);
    }

    public async Variant get_uri_infos (string raw_uri) throws GLib.DBusError, GLib.IOError {
        Idle.add (get_uri_infos.callback);
        yield;
        var uri = escape (raw_uri);
        Sqlite.Statement stmt;

        var vb = new VariantBuilder (new VariantType ("(as)"));
        int rc = db.prepare_v2 ("select modified_time, content_type, color from tags where uri='%s'".printf (uri),
                                -1, out stmt);
        assert (rc == Sqlite.OK);
        rc = stmt.step ();
        vb.open (new VariantType ("as"));

        switch (rc) {
        case Sqlite.DONE:
            break;
        case Sqlite.ROW:
            vb.add ("s", stmt.column_text (0));
            var content_type = stmt.column_text (1);
            vb.add ("s", (content_type != null) ? content_type : "");
            vb.add ("s", stmt.column_text (2));
            break;
        default:
            warning ("[get_uri_infos]: Error: %d, %s\n", rc, db.errmsg ());
            break;
        }

        vb.close ();
        return vb.end ();
    }

    public async bool delete_entry (string uri) throws GLib.DBusError, GLib.IOError {
        Idle.add (delete_entry.callback);
        yield;
        string c = "delete from tags where uri='" + uri + "'";
        int rc = db.exec (c, null, null);

        if (rc != Sqlite.OK) {
            warning ("[delete_entry: SQL error]  %d, %s\n", rc, db.errmsg ());
            return false;
        }

        return true;
    }

/************* Used for maintenance only *************/

    public bool show_table (string table) throws GLib.DBusError, GLib.IOError {
        stdout.printf ("show_table\n");
        string consult = "select * from " + table;
        int rc = db.exec (consult, show_table_callback, null);

        if (rc != Sqlite.OK) {
            warning ("[show_table: SQL error]: %d, %s\n", rc, db.errmsg ());
            return false;
        }

        return true;
    }

    public bool clear_db () throws GLib.DBusError, GLib.IOError {
        string c = "delete from tags";
        int rc = db.exec (c, null, null);

        if (rc != Sqlite.OK) {
            warning ("[clear_db: SQL error]  %d, %s\n", rc, db.errmsg ());
            return false;
        }

        return true;
    }

    private bool has_column (string table_name, string column_name) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2 ("PRAGMA table_info(%s)".printf (table_name), -1, out stmt);
        assert (res == Sqlite.OK);

        while (true) {
            res = stmt.step ();

            if (res == Sqlite.DONE) {
                break;
            } else if (res != Sqlite.ROW) {
                critical ("has_column %s".printf (table_name), res);
                break;
            } else {
                string column = stmt.column_text (1);
                if (column != null && column == column_name) {
                    return true;
                }
            }
        }

        return false;
    }

    private bool add_column (string table_name, string column_name, string column_constraints) {
        Sqlite.Statement stmt;
        int res = db.prepare_v2 ("ALTER TABLE %s ADD COLUMN %s %s".printf (table_name, column_name,
            column_constraints), -1, out stmt);

        assert (res == Sqlite.OK);
        res = stmt.step ();

        if (res != Sqlite.DONE) {
            critical ("Unable to add column %s %s %s: (%d) %s", table_name, column_name, column_constraints,
                res, db.errmsg ());

            return false;
        }

        return true;
    }

    private void upgrade_database () {
        if (!has_column ("tags", "content_type")) {
            message ("upgrade_database: adding content_type column to tags");

            if (!add_column ("tags", "content_type", "TEXT")) {
                warning ("UPGRADE_ERROR");
            }
        }

        if (!has_column ("tags", "modified_time")) {
            message ("upgrade_database: adding modified_time column to tags");

            if (!add_column ("tags", "modified_time", "INTEGER DEFAULT 0")) {
                warning ("UPGRADE_ERROR");
            }
        }

        if (!has_column ("tags", "dir")) {
            message ("upgrade_database: adding dir column to tags");

            if (!add_column ("tags", "dir", "TEXT")) {
                warning ("UPGRADE_ERROR");
            }
        }
    }
}
