/*  
 * Copyright (C) 2011 Marlin Developers
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Author: ammonkey <am.monkeyd@gmail.com>
 */ 

/* TODO merge with ctags plugin */

[DBus (name = "org.elementary.marlin.db")]
interface CTags : Object {
    public abstract async bool record_uris (Variant[] entries, string directory) 	throws IOError;
}

namespace Marlin.View {

    public class Tags : Object {

        private CTags ctags;

        public Tags() {
            try {
                ctags = Bus.get_proxy_sync (BusType.SESSION, "org.elementary.marlin.db",
                                           "/org/elementary/marlin/db");
            } catch (IOError e) {
                stderr.printf ("%s\n", e.message);
            }
        }

        private Variant add_entry (GOF.File gof)
        {
            char* ptr_arr[4];
            ptr_arr[0] = gof.uri;
            ptr_arr[1] = gof.get_ftype ();
            ptr_arr[2] = gof.info.get_attribute_uint64 (FileAttribute.TIME_MODIFIED).to_string ();
            ptr_arr[3] = gof.color.to_string ();

            return new Variant.strv ((string[]) ptr_arr);
        }

        public async void set_color (FM.Directory.View view, int n) throws IOError {
            Variant[] entries = null;
            unowned List<GOF.File> files = view.get_selection ();
            /*if (n == 0)
              yield tags.deleteEntry(file.uri);
              else*/
            //yield tags.setColor(file.uri, n);
            foreach (var file in files) {
                file.color = n;
                entries +=  add_entry (file);
            }
            if (entries != null) {
                try {
                    yield ctags.record_uris (entries, ((GOF.File) files.data).uri);
                } catch (Error err) {
                    warning ("%s", err.message);
                }
            }
        }

#if 0
        public async void get_color (GOF.File myfile) throws IOError {
            if (myfile == null) 
                return;
            /*int n = yield tags.getColor(myfile.uri);
              myfile.color = Preferences.tags_colors[n];*/
            var rc = yield tags.get_uri_infos (myfile.uri);
            VariantIter iter = rc.iterator ();
            //warning ("iter n_children %d", (int) iter.n_children ());
            assert (iter.n_children () == 1);
            VariantIter row_iter = iter.next_value ().iterator ();
            //warning ("row_iter n_children %d", (int) row_iter.n_children ());

            if (row_iter.n_children () == 2) {
                unowned string type = row_iter.next_value ().get_string ();
                int n = int.parse (row_iter.next_value ().get_string ());
                myfile.tagstype = type;
                myfile.color = Preferences.tags_colors[n];
                myfile.update_type ();
                //message ("grrrrrr %s %s %d %s", myfile.name, type, n, myfile.ftype);
            }

        }
#endif   

    }
}

