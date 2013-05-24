using Gtk;
using GLib;

[CCode (cprefix = "MarlinConnectServerDialog", lower_case_cprefix = "marlin_connect_server_dialog_", cheader_filename = "../../src/marlin-connect-server-dialog.h")]
namespace Marlin.ConnectServerDialog {
    static void show_connect_server_dialog(Gtk.Widget widget);
}
