/* -*- Mode: C; indent-tabs-mode: t; c-basic-offset: 4; tab-width: 4 -*- */
/*
 * Copyright (C) 2010 Jordi Puigdellívol <jordi@gloobus.net>
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

using GLib;
using Sqlite;

[DBus (name = "org.elementary.marlin.db")]
public class MarlinTags : Object {

    protected static Sqlite.Database db;

    public MarlinTags(){
        openMarlinDB();
    }

    protected static void fatal(string op, int res) {
        error("%s: [%d] %s", op, res, db.errmsg());
    }

    private static int show_table_callback (int n_columns, string[] values, string[] column_names){
        for (int i = 0; i < n_columns; i++) {
            stdout.printf ("%s = %s\n", column_names[i], values[i]);
        }
        stdout.printf ("\n");

        return 0;
    }

    public bool openMarlinDB()
    {
        File home_dir = File.new_for_path (Environment.get_home_dir ());
        File data_dir = home_dir.get_child(".config").get_child("marlin");

        try {
            if (!data_dir.query_exists(null))
                data_dir.make_directory_with_parents(null);
        } catch (Error err) {
            stderr.printf("Unable to create data directory %s: %s", data_dir.get_path(), err.message);
        }

        string marlin_db_path = data_dir.get_child("marlin.db").get_path();
        //The database must exists, add here the full path
        print("Database path: %s \n", marlin_db_path);
        openDB(marlin_db_path);
    }

    private bool openDB(string dbpath){
        int rc = Sqlite.Database.open_v2(dbpath, out db, Sqlite.OPEN_READWRITE | Sqlite.OPEN_CREATE, null);

        if (rc != Sqlite.OK) {
            stderr.printf ("Can't open database: %d, %s\n", rc, db.errmsg ());
            return false;
        }

        // disable synchronized commits for performance reasons ... this is not vital
        rc = db.exec("PRAGMA synchronous=OFF");
        if (rc != Sqlite.OK)
            stdout.printf("Unable to disable synchronous mode %d, %s\n", rc, db.errmsg ());


        Sqlite.Statement stmt;
        int res = db.prepare_v2("CREATE TABLE IF NOT EXISTS tags ("
            + "id INTEGER PRIMARY KEY, "
            + "uri TEXT UNIQUE NOT NULL, "
            + "color INTEGER, "
            + "tags TEXT NULL"
            + ")", -1, out stmt);
        assert(res == Sqlite.OK);
        res = stmt.step();
        if (res != Sqlite.DONE)
            fatal("create tags table", res);

        return true;
    }

    private async bool isFileInDB(string uri){
        if(yield getColor(uri) == 0)
            return false;
        else
            return true;

    }

    public async void uris_setColor(string[] uris, int color){
        Idle.add (uris_setColor.callback);
        yield;
        string c = "";

        foreach (string uri in uris) {
            if (color != 0)
                c += "insert or replace into tags(uri,color) values ('"+uri+"',"+color.to_string()+");\n";
            else
                c += "delete from tags where uri='" + uri + "';\n";
            //stdout.printf("test uri %s\n", uri);
            stdout.printf("[uri_setColor]: %s\n", uri);
        }
        int rc = db.exec (c, null, null);
        if (rc != Sqlite.OK) { 
            stderr.printf ("[uris_setColor: SQL error]  %d, %s\n", rc, db.errmsg ());
        }
    }

    public async bool setColor(string uri, int color){
        Idle.add (setColor.callback);
        yield;
        string c = "";

        /*if(yield isFileInDB(uri)){
            c = "update tags set color = "+color_string+" where uri= '"+uri+"'";
        }
        else{
            c = "insert into tags(uri,color) values ('"+uri+"',"+color_string+")";	
        }*/
        c = "insert or replace into tags(uri,color) values ('"+uri+"',"+color.to_string()+")";	

        int rc = db.exec (c, null, null);
        if (rc != Sqlite.OK) { 
            stderr.printf ("[addColor: SQL error]  %d, %s\n", rc, db.errmsg ());
            return false;
        }
        //stdout.printf("[Consult]: %s\n",c);
        stdout.printf("[setColor]: %s\n", uri);

        return true;		
    }

    public async int getColor(string uri)
    {
        Idle.add (getColor.callback);
        yield;
        string c = "select color from tags where uri='" + uri + "'";
        Statement stmt;
        int rc = 0;
        int col, cols;
        //string txt = "-1";
        string txt = "0";

        if ((rc = db.prepare_v2 (c, -1, out stmt, null)) == 1) {
            printerr ("[getColor]: SQL error: %d, %s\n", rc, db.errmsg ());
            return -1;
        }
        cols = stmt.column_count();
        do {
            rc = stmt.step();
            switch (rc) {
            case Sqlite.DONE:
                break;
            case Sqlite.ROW:
                for (col = 0; col < cols; col++) {
                    txt = stmt.column_text(col);
                    //print ("%s = %s\n", stmt.column_name (col), txt);
                }
                break;
            default:
                printerr ("[getColor]: Error: %d, %s\n", rc, db.errmsg ());
                break;
            }
        } while (rc == Sqlite.ROW);
        //stdout.printf("[getColor]: %s\n", txt);

        return txt.to_int();
    }

    public async bool deleteEntry(string uri)
    {
        Idle.add (deleteEntry.callback);
        yield;
        //string uri = file.get_uri();
        string c = "delete from tags where uri='" + uri + "'";
        int   rc = db.exec (c, null, null);

        if (rc != Sqlite.OK) { 
            stderr.printf ("[deleteEntry: SQL error]  %d, %s\n", rc, db.errmsg ());
            return false;
        }

        return true;		
    }

    public bool showTable(string table){
        stdout.printf("showTable\n");
        string consult = "select * from " + table;
        int rc = db.exec (consult, show_table_callback, null);

        if (rc != Sqlite.OK) { 
            stderr.printf ("[showTable: SQL error]: %d, %s\n", rc, db.errmsg ());
            return false;
        }

        return true;
    }

    public bool clearDB(){
        string c = "delete from tags"; 
        int   rc = db.exec (c, null, null);

        if (rc != Sqlite.OK) { 
            stderr.printf ("[clearDB: SQL error]  %d, %s\n", rc, db.errmsg ());
            return false;
        }

        return true;	
    }
}

/* =============== Main ==================== */
/*void main (string[] args) {

  MarlinTags t = new MarlinTags();

  t.openMarlinDB();

  t.setColor("file:///home/jordi"	,MARLIN_RED);
  t.setColor("file:///home/dev"	,MARLIN_YELLOW);

//t.deleteEntry(File.new_for_path ("/home/dev"));	//When deleting files
//t.deleteEntry("/home/documents");

//t.clearDB();
t.showTable("tags");


// DBUS Things
print("\n\nColor for file is %i\n", 
t.getColor("file:///home/jordi"));
}*/


void on_bus_aquired (DBusConnection conn) {
    try {
        conn.register_object ("/org/elementary/marlin/db", new MarlinTags ());
    } catch (IOError e) {
        stderr.printf ("Could not register service\n");
    }
}

void main () {
    Bus.own_name (BusType.SESSION, "org.elementary.marlin.db", BusNameOwnerFlags.NONE,
                  on_bus_aquired,
                  () => {},
                  () => stderr.printf ("Could not aquire name\n"));

    new MainLoop ().run ();
}

