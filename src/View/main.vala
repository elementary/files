
void main ( string[] args ) {
    stdout.printf("test\n");

	Gtk.init(ref args);
    var window = new Marlin.View.Window("/home");

    window.show_about.connect(about);
    window.up.connect(() => { stdout.printf("signal: up\n"); });
    window.back.connect(() => { stdout.printf("signal: back\n"); });
    window.forward.connect(() => { stdout.printf("signal: forward\n"); });
    window.refresh.connect(() => { stdout.printf("signal: refresh\n"); });
    window.quit.connect(() => { stdout.printf("signal: quit\n"); Gtk.main_quit(); });
    window.path_changed.connect((path) => {stdout.printf("signal: path_changed(%s)\n", path); });
    window.content = new Gtk.Label("Loaded");
    
	Gtk.main();
}

static void about()
{
	Gtk.AboutDialog about = new Gtk.AboutDialog ();
	about.program_name = "Marlin";
	about.icon_name = "system-file-manager";
	about.logo_icon_name = "system-file-manager";
	about.website = "http://www.elementary-project.com";
	about.website_label = "Website";
	about.copyright = "Copyright 2010 elementary Developers";
	about.authors = {
		"ammonkey <am.monkeyd@gmail.com>",
		"Mathijs Henquet <mathijs.henquet@gmail.com>"
	};
	about.artists = { 
		"Daniel Foré <dan@elementary-project.com>"
	};
	
	about.run ();
	
	about.destroy();
}