// ModeButton.cs
// 
// Copyright (C) 2008 Christian Hergert <chris@dronelabs.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.


using Gtk;
using Gdk;


namespace Marlin.View.Chrome
{
	public class ModeButton : Gtk.EventBox
	{
		public signal void mode_added(int index, Widget widget);
		public signal void mode_removed(int index, Widget widget);
		public signal void mode_changed(Widget widget);
		
		private int _selected = -1;
		private int _hovered = -1;
		private HBox box;

		public ModeButton ()
		{
			events |= EventMask.POINTER_MOTION_MASK
			       |  EventMask.BUTTON_PRESS_MASK
			       |  EventMask.VISIBILITY_NOTIFY_MASK;
			       //|  EventMask.SCROLL_MASK;

			box = new HBox (true, 1);
			box.border_width = 0;
			add (box);
			box.show ();
			
			visibility_notify_event.connect(on_leave_notify_event);
			button_press_event.connect(on_button_press_event);
			motion_notify_event.connect(on_motion_notify_event);
			scroll_event.connect(on_scroll_event);	
			
			draw.connect(on_draw);
		}

		public int selected {
			get {
				return this._selected;
			}
			set {
				if (value < -1 || value >= box.get_children().length())
					return;
				
				if (_selected >= 0)
					box.get_children ().nth_data(_selected).set_state(StateType.NORMAL);

				_selected = value;
				box.get_children().nth_data(_selected).set_state(StateType.SELECTED);
				queue_draw ();

				Widget selectedItem = value >= 0 ? box.get_children().nth_data(value) : null;
				mode_changed (selectedItem);
			}
		}

		public int hovered {
			get {
				return this._hovered;
			}
			set {
				/*if (value < -1 || value >= box.get_children().Length)
					throw new ArgumentOutOfRangeException (); */
					
				_hovered = value;
				queue_draw ();
			}
		}

		public void append (Widget widget)
		{
			box.pack_start (widget, true, true, 5);
			int index = (int) box.get_children().length() - 2;
			mode_added (index, widget);
		}

		public new void remove (int index)
		{
			Widget child = box.get_children().nth_data(index);
			box.remove (child);
			if (_selected == index)
				_selected = -1;
			else if (_selected >= index)
				_selected--;
			if (_hovered >= index)
				_hovered--;
			this.mode_removed (index, child);
			this.queue_draw ();
		}

        public void focus(Widget widget){
            stdout.printf("Set focus\n");

            int select = box.get_children().index(widget);
			
			if (_selected >= 0)
				box.get_children ().nth_data(_selected).set_state(StateType.NORMAL);

			_selected = select;
			widget.set_state(StateType.SELECTED);
			queue_draw ();

			Widget selectedItem = widget;
        }
		
		protected bool on_scroll_event(EventScroll evnt){
			switch(evnt.direction){
				case ScrollDirection.UP:
					if (selected < box.get_children().length() - 1)
						selected++;
					break;
				case ScrollDirection.DOWN:
					if (selected > 0)
						selected--;
					break;
			}
				
			return true;	
		}
		
		protected bool on_button_press_event(EventButton evnt)
		{
			if (_hovered > -1 && _hovered != _selected)
				selected = _hovered;
				
			return true;
		}

		protected bool on_leave_notify_event(Event evnt)
		{
			_hovered = -1;
			queue_draw ();
			
			return true;
		}

		protected bool on_motion_notify_event(EventMotion evnt)
		{
			int n_children = (int) box.get_children().length();
			if (n_children < 1)
				return false;
			
			Allocation allocation;
			get_allocation(out allocation);	
				
			double child_size = allocation.width / n_children;
			int i = -1;

			if (child_size > 0)
				i = (int) (evnt.x / child_size);

			if (i >= 0 && i < n_children)
				this.hovered = i;
				
			return false;
		}

		protected bool on_draw(Cairo.Context cr)
		{
			int width, height;
			float item_x, item_width;
			
			width = get_allocated_width();
			height = get_allocated_height();
			
			var n_children = (int) box.get_children().length();
			
			style.draw_box (cr, StateType.NORMAL, ShadowType.IN, this, "button", 0, 0, width, height);
			if (_selected >= 0) {
				if (n_children > 1) {
					item_width = width / n_children;
					item_x = (item_width * _selected) + 1;
				}
				else {
					item_x = 0;
					item_width = width;
				}
				
				cr.move_to(item_x, 0);
				cr.line_to(item_x, height);
				cr.line_to(item_x+item_width, height);
				cr.line_to(item_x+item_width, 0);
				cr.clip();
				
				style.draw_box (cr, StateType.SELECTED,
							    ShadowType.ETCHED_OUT, this, "button",
							    0, 0,
							    width, height);
			}
			
			cr.restore();
			cr.save();

			if (hovered >= 0 && selected != hovered) {
				if (n_children > 1) {
					item_width = width / n_children;
					if (hovered == 0)
						item_x = 0;
					else
						item_x = item_width * hovered + 1;
				}
				else {
					item_x = 0;
					item_width = width;
				}
				
				cr.move_to(item_x, 0);
				cr.line_to(item_x, height);
				cr.line_to(item_x+item_width, height);
				cr.line_to(item_x+item_width, 0);
				cr.clip();

				style.draw_box (cr, StateType.PRELIGHT,
							    ShadowType.IN, this, "button",
							    0, 0,
							    width, height);
			}
			
			cr.restore();

			propagate_draw (box, cr);
			
			return true;
		}
	}
}
