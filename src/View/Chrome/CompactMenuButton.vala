using Gtk;

namespace Marlin.View.Chrome {
	
	public class CompactMenuButton : ToggleToolButton
	{
		Menu menu;

		public CompactMenuButton.from_stock (string stock_image, IconSize size, string label, Menu m)
		{
			Image image = new Image.from_stock(stock_image, size);
			
			this(image, label, m);
		}

		public CompactMenuButton (Image image, string label, Menu _menu)
		{
			icon_widget = image;
			Label l = new Label (label);
			l.use_underline = true;
			label_widget = l;
			can_focus = true;
			menu = _menu;
			menu.attach_to_widget (this, null);
			menu.deactivate.connect(() => {
				active = false;
			});
			
			clicked.connect(on_clicked);
			button_press_event.connect(on_button_press_event);
			mnemonic_activate.connect(on_mnemonic_activate);

			this.show_all ();
		}

		protected bool on_button_press_event (Gdk.EventButton ev)
		{
			custom_popup_menu (ev);
			return true;
		}

		protected void on_clicked ()
		{
			menu.select_first (true);
			custom_popup_menu (null);
		}

		protected bool on_mnemonic_activate (bool group_cycling)
		{
			// ToggleButton always grabs focus away from the editor,
			// so reimplement Widget's version, which only grabs the
			// focus if we are group cycling.
			if (!group_cycling) {
				activate ();
			} else if (can_focus) {
				grab_focus ();
			}

			return true;
		}
		

		void custom_popup_menu(Gdk.EventButton? ev /*, GetMenuPosition */)
		{
			menu.deactivate.connect(deactivate_menu);
			try {
				menu.popup (null,
				            null,
				            get_menu_position,
				            (ev == null) ? 0 : ev.button,
				            (ev == null) ? get_current_event_time() : ev.time);
			} catch {
				menu.popup (null,
				            null,
				            null,
				            (ev == null) ? 0 : ev.button,
				            (ev == null) ? get_current_event_time() : ev.time);
			}

			// Highlight the parent
			if (menu.attach_widget != null)
				menu.attach_widget.set_state(StateType.SELECTED);
		}
		
		void deactivate_menu ()
		{
			menu.popdown ();

			// Unhighlight the parent
			if (menu.attach_widget != null)
				menu.attach_widget.set_state(Gtk.StateType.NORMAL);
		}
		
		void get_menu_position (Menu menu, out int x, out int y, out bool push_in)
		{
			if (menu.attach_widget == null ||
			    menu.attach_widget.get_window() == null) {
				// Prevent null exception in weird cases
				x = 0;
				y = 0;
				push_in = true;
				return;
			}
			
			menu.attach_widget.get_window().get_origin (out x, out y);
			Allocation allocation;
			menu.attach_widget.get_allocation(out allocation);
			
			
			x += allocation.x;
			y += allocation.y;

			int width, height;
			menu.get_size_request(out width, out height);
			
			if (y + height >= menu.attach_widget.get_screen().get_height())
				y -= height;
			else
				y += allocation.height;

			push_in = true;
		}
	}
}
