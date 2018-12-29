/***
    Copyright (c) 2011 Marlin Developers

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, Inc.,, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    Author: ammonkey <am.monkeyd@gmail.com>
***/

GLib.List<GOF.CallWhenReady>? callwhenready_cache = null;

public class GOF.CallWhenReady : Object {
    public delegate void call_when_ready_func (GLib.List<GOF.File>files);

    public GLib.List<GOF.File> files;
    private unowned call_when_ready_func? f;
    private GLib.List<GOF.File>? call_when_ready_list = null;


    public CallWhenReady (GLib.List<GOF.File> _files, call_when_ready_func? _f = null) {
        files = _files.copy_deep ((GLib.CopyFunc) GLib.Object.ref);
        f = _f;

        int count = 0;
        foreach (unowned GOF.File gof in files) {
            if (gof.info == null) {
                call_when_ready_list.prepend (gof);
                query_info_async.begin (gof, file_ready);
            } else {
                count++;
            }
        }

        /* we didn't need to queue anything, all the infos were available */
        if (count > 0 && count == files.length () && f != null) {
            f (files);
        }

        callwhenready_cache.prepend (this);
    }

    private void file_ready (GOF.File gof) {
        gof.update ();
    }

    /**TODO** move this to GOF.File */

    private unowned string gio_default_attributes = "standard::is-hidden,standard::is-backup,standard::is-symlink," +
    "standard::type,standard::name,standard::display-name,standard::fast-content-type,standard::size," +
    "standard::symlink-target,access::*,time::*,owner::*,trash::*,unix::*,id::filesystem,thumbnail::*";

    private delegate void func_query_info (GOF.File gof);

    private async void query_info_async (GOF.File gof, func_query_info? fqi = null) {
        try {
            gof.info = yield gof.location.query_info_async (gio_default_attributes,
                                                            FileQueryInfoFlags.NONE,
                                                            Priority.DEFAULT);
            if (fqi != null) {
                fqi (gof);
            }
        } catch (Error err) {
            debug ("query info failed, %s %s", err.message, gof.uri);
            if (err is IOError.NOT_FOUND) {
                gof.exists = false;
            }

            if (err is IOError.NOT_MOUNTED) {
                gof.is_mounted = false;
            }
        }

        call_when_ready_list.remove (gof);
        if (call_when_ready_list == null) {
            debug ("call when ready OK - empty list");
            if (f != null) {
                f (files);
            }
        }

        callwhenready_cache.remove (this);
    }
}
