/*
 * Copyright (C) ammonkey 2011 <am.monkeyd@gmail.com>
 * 
 * Marlin is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * Marlin is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;
using Marlin;

[DBus (name = "org.elementary.marlin.db")]
interface MarlinDaemon : Object {
    //public abstract async HashTable<string,Variant> get_uri_infos_from_directory (string directory) throws IOError;
    public abstract async Variant get_uri_infos (string raw_uri) throws IOError;
    public abstract async bool record_uris (Variant[] entries, string directory) 	throws IOError;

}


public class Marlin.Plugins.CTags : Marlin.Plugins.Base
{
    private MarlinDaemon daemon;
    //GOF.Directory.Async directory;
    GOF.File directory;
    private bool is_user_dir;
    private bool ignore_dir;

    private Queue<GOF.File> unknowns;
    private Queue<GOF.File> knowns;
    private uint idle_consume_unknowns = 0;
    private uint t_consume_knowns = 0;
    private Cancellable cancellable;

    public CTags()
    {
        unknowns = new Queue<GOF.File> ();
        knowns = new Queue<GOF.File> ();
        cancellable = new Cancellable ();

        try {
            daemon = Bus.get_proxy_sync (BusType.SESSION, "org.elementary.marlin.db",
                                         "/org/elementary/marlin/db");
        } catch (IOError e) {
            stderr.printf ("%s\n", e.message);
        }
    }

    /*private void file_info_update (HashTable<string,Variant> rc, GOF.File file)
      {
      Variant row = rc.lookup (file.uri);
      if (row == null)
      return;

      VariantIter iter = row.iterator ();
      warning ("iter n_children %d", (int) iter.n_children ());
      assert (iter.n_children () == 1);
      VariantIter row_iter = iter.next_value ().iterator ();
      warning ("row_iter n_children %d", (int) row_iter.n_children ());

      if (row_iter.n_children () == 2) {
      unowned string type = row_iter.next_value ().get_string ();
      int n = int.parse (row_iter.next_value ().get_string ());
      file.tagstype = type;
    //file.color = Preferences.tags_colors[n];
    file.update_type ();
    message ("grrrrrr %s %d", type, n);
    }
    }*/

    /*private async void files_infos_updates ()
      {
      var rc = yield daemon.get_uri_infos_from_directory (directory.file.uri);

      foreach (var file in directory.unknown_types) {
      message ("unknown %s %s", file.name, file.ftype);
      file_info_update (rc, file);
      }
      directory.unknown_types = null;


      }*/

    /* Arbitrary user dir list */
    private const string users_dirs[2] = {
        "file:///home",
        "file:///media"
    }; 

    private bool f_is_user_dir (string uri) {
        return_val_if_fail (uri != null, false);
        foreach (var duri in users_dirs) {
            if (Posix.strncmp (uri, duri, duri.length) == 0)
                return true;
        }

        return false;
    }

    private bool f_ignore_dir (string uri) {
        return_val_if_fail (uri != null, true);
        
        var idir = "file:///tmp";
        if (Posix.strncmp (uri, idir, idir.length) == 0)
            return true;

        return false;
    }

    public override void directory_loaded (void* user_data)
    {
        message  ("CANCEL");
        cancellable.cancel ();


        if (idle_consume_unknowns > 0) {
            Source.remove (idle_consume_unknowns);
            idle_consume_unknowns = 0;
        }

        unknowns.clear ();
        cancellable.reset ();
        
        //directory = GOF.Directory.Async.from_file(((Object[])user_data)[2] as GOF.File);
        directory = ((Object[])user_data)[2] as GOF.File;
        //warning ("CTags Plugin dir %s", directory.file.uri);
        warning ("CTags Plugin dir %s", directory.uri);
        is_user_dir = f_is_user_dir (directory.uri);
        ignore_dir = f_ignore_dir (directory.uri);
    }

    //private Variant add_entry (string uri, string content_type, int modified_time)
    private Variant add_entry (GOF.File gof)
    {
        char* ptr_arr[4];
        ptr_arr[0] = gof.uri;
        ptr_arr[1] = gof.get_ftype ();
        ptr_arr[2] = gof.info.get_attribute_uint64 (FileAttribute.TIME_MODIFIED).to_string ();
        ptr_arr[3] = gof.color.to_string ();

        return new Variant.strv ((string[]) ptr_arr);
    }

    private async void consume_knowns_queue ()
    {
        Variant[] entries = null;
        GOF.File gof;
        while ((gof = knowns.pop_head ()) != null) {
            //warning ("--- known %s", gof.name);
            entries += add_entry (gof);
        }

        if (entries != null) {
            warning ("--- known entries %d", entries.length);
            try {
                yield daemon.record_uris (entries, directory.uri);
            } catch (Error err) {
                warning ("%s", err.message);
            }
        }
    }

    private async void consume_unknowns_queue ()
    {
        GOF.File gof = null;

        var count = unknowns.get_length ();
        message ("unknows queue nb: %u", count);
        if (count > 10) {
            /* query info the whole dir, we can clear the whole unknowns queue */
            unknowns.clear ();
            try {
                var e = yield directory.location.enumerate_children_async (FileAttribute.STANDARD_NAME+","+ FileAttribute.STANDARD_CONTENT_TYPE, 0, 0, cancellable);
                while (true) {
                    var files = yield e.next_files_async (200, 0, cancellable);
                    if (files == null)
                        break;

                    foreach (var file_info in files)
                    {
                        GLib.File loc = directory.location.get_child ((string) file_info.get_name());
                        gof = GOF.File.get (loc);
                        if (gof != null)
                            add_to_knowns_queue (gof, file_info);
                    }
                }
            } catch (Error err1) {
                warning ("dir query_info failed: %s %s", err1.message, directory.uri);
            }
        } else {
            while ((gof = unknowns.pop_head ()) != null) {
                //warning ("--- unknown %s", gof.name);
                try {
                    //var info = gof.location.query_info (FileAttribute.STANDARD_CONTENT_TYPE, 0);
                    var info = yield gof.location.query_info_async (FileAttribute.STANDARD_CONTENT_TYPE, 0, 0, cancellable);
                    warning ("--- unknown query_info %s", gof.info.get_name ());
                    add_to_knowns_queue (gof, info);
                } catch (Error err2) {
                    warning ("query_info failed: %s %s", err2.message, gof.uri);
                }

            }
        }
        idle_consume_unknowns = 0;
    }

    private void add_to_knowns_queue (GOF.File file, FileInfo info) {
        file.tagstype = info.get_content_type ();
        file.update_type ();

        knowns.push_head (file);
        if (t_consume_knowns != 0) {
            Source.remove (t_consume_knowns);
            t_consume_knowns = 0;
        }
        t_consume_knowns = Timeout.add (300, () => { 
                                        consume_knowns_queue (); 
                                        return false;
                                        });
    }

    private void add_to_unknowns_queue (GOF.File file) {
        if (file.get_ftype () == "application/octet-stream") {
            unknowns.push_head (file);

            if (idle_consume_unknowns == 0)
                idle_consume_unknowns = Idle.add (() => { 
                                                  consume_unknowns_queue ();
                                                  return false;
                                                  });
        }
    }

    private async void rreal_update_file_info (GOF.File file)
    {
        //warning ("ctags update %s", file.name);
        try {
            var rc = yield daemon.get_uri_infos (file.uri);

            VariantIter iter = rc.iterator ();
            //warning ("iter n_children %d", (int) iter.n_children ());
            assert (iter.n_children () == 1);
            VariantIter row_iter = iter.next_value ().iterator ();
            //warning ("row_iter n_children %d", (int) row_iter.n_children ());

            if (row_iter.n_children () == 3) {
                uint64 modified = int64.parse (row_iter.next_value ().get_string ());
                //message ("%s %d %d", file.name, (int) file.info.get_attribute_uint64 (FileAttribute.TIME_MODIFIED), (int) modified);
                unowned string type = row_iter.next_value ().get_string ();
                file.color = int.parse (row_iter.next_value ().get_string ());
                /* check modified time field only on user dirs. We don't want to query again and
                 * again system directories */
                if (is_user_dir &&
                    file.info.get_attribute_uint64 (FileAttribute.TIME_MODIFIED) > modified) {
                    add_to_unknowns_queue (file);
                    return;
                }
                if (type.length > 0 && file.get_ftype () == "application/octet-stream") {
                    if (type != "application/octet-stream") {
                        file.tagstype = type;
                        file.update_type ();
                    }
                }
                //message ("grrrrrr %s %s %d %s", myfile.name, type, n, myfile.ftype);
            } else {
                add_to_unknowns_queue (file);
            }
        } catch (Error err) {
            warning ("%s", err.message);
        }
    }

    public override void update_file_info(GOF.File file) 
    {
        return_if_fail (file != null);
        if (!ignore_dir
            &&file != null && file.info != null
            && (!file.is_hidden || GOF.Preferences.get_default ().pref_show_hidden_files))
            /*&& file.ftype == "application/octet-stream")*/
            /*if (file.ftype == "application/octet-stream")*/
            rreal_update_file_info (file);
    }
}


public Marlin.Plugins.Base module_init()
{
    return new Marlin.Plugins.CTags();
}
