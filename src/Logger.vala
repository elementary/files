//  
//  Copyright (C) 2011 Robert Dyer
// 
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
// 
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
// 
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
// 

namespace Marlin {

	public enum LogLevel {
		DEBUG,
		INFO,
		NOTIFY,
		WARN,
		ERROR,
		FATAL,
	}
	
	enum ConsoleColor {
		BLACK,
		RED,
		GREEN,
		YELLOW,
		BLUE,
		MAGENTA,
		CYAN,
		WHITE,
	}
	
	public class Logger : GLib.Object {
		
		public static LogLevel DisplayLevel { get; set; default = LogLevel.WARN; }
		
		static string AppName { get; set; }
		
		static Regex re;
		
		public static void initialize (string app_name) {
		
			AppName = app_name;
			/*try {
				re = new Regex ("""(.*)\.vala(:\d+): (.*)""");
			} catch { }*/
			
			Log.set_default_handler (glib_log_func);
		}
		
		static string format_message (string msg) {
		
			if (re != null && re.match (msg)) {
				var parts = re.split (msg);
				return "[%s%s] %s".printf (parts[1], parts[2], parts[3]);
			}
			return msg;
		}
		
		public static void notification (string msg) {
			write (LogLevel.NOTIFY, format_message (msg));
		}
		
		static string get_time () {
		
			var now = new DateTime.now_local ();
			return "%.2d:%.2d:%.2d.%.6d".printf (now.get_hour (), now.get_minute (), now.get_second (), now.get_microsecond ());
		}
		
		static void write (LogLevel level, string msg) {
		
			if (level < DisplayLevel)
				return;
				
			set_color_for_level (level);
			stdout.printf ("[%s %s]", level.to_string ().substring (17), get_time ());
			
			reset_color ();
			stdout.printf (" %s\n", msg);
		}
		
		static void set_color_for_level (LogLevel level) {
		
			switch (level) {
				case LogLevel.DEBUG:
					set_foreground (ConsoleColor.GREEN);
					break;
				case LogLevel.INFO:
					set_foreground (ConsoleColor.BLUE);
					break;
				case LogLevel.NOTIFY:
					set_foreground (ConsoleColor.MAGENTA);
					break;
				case LogLevel.WARN:
					set_foreground (ConsoleColor.YELLOW);
					break;
				case LogLevel.ERROR:
					set_foreground (ConsoleColor.RED);
					break;
				case LogLevel.FATAL:
					set_background (ConsoleColor.RED);
					set_foreground (ConsoleColor.WHITE);
					break;
			}
		}
		
		static void reset_color () {
			stdout.printf ("\x001b[0m");
		}
		
		static void set_foreground (ConsoleColor color) {
			set_color (color, true);
		}
		
		static void set_background (ConsoleColor color) {
			set_color (color, false);
		}
		
		static void set_color (ConsoleColor color, bool isForeground) {
		
			var color_code = color + 30 + 60;
			if (!isForeground)
				color_code += 10;
			stdout.printf ("\x001b[%dm", color_code);
		}
		
		static void glib_log_func (string? d, LogLevelFlags flags, string msg) {
			var domain = "";
			if (d != null)
				domain = "[%s] ".printf (d);
			
			var message = msg.replace ("\n", "").replace ("\r", "");
			message = "%s%s".printf (domain, message);
			
			switch (flags) {
				case LogLevelFlags.LEVEL_CRITICAL:
					write (LogLevel.FATAL, format_message (message));
					write (LogLevel.FATAL, format_message (AppName + " will not function properly."));
					break;
				
				case LogLevelFlags.LEVEL_ERROR:
					write (LogLevel.ERROR, format_message (message));
					break;
				
				case LogLevelFlags.LEVEL_INFO:
				case LogLevelFlags.LEVEL_MESSAGE:
					write (LogLevel.INFO, format_message (message));
					break;
				
				case LogLevelFlags.LEVEL_DEBUG:
					write (LogLevel.DEBUG, format_message (message));
					break;
				
				case LogLevelFlags.LEVEL_WARNING:
				default:
					write (LogLevel.WARN, format_message (message));
					break;
			}
		}
		
	}
	
}

