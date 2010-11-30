
public class Log : Object{
    public enum Level{
        FATAL,
        ERROR,
        WARN,
        NOTIFY,
        INFO,
        DEBUG,
        UNDEFINED
    }

    public enum Color{
        Black,
		DarkRed,
		DarkGreen,
		DarkYellow,
		DarkBlue,
		DarkMagenta,
		DarkCyan,
		Gray,

		// Light colors
		DarkGray,
		Red,
		Green,
		Yellow,
		Blue,
		Magenta,
		Cyan,
		White,
		
		// Reset sequence
		Reset
	}
	
	private static string get_color_code(Color color, bool foreground){
	    var light = false;
	    var color_id = 0;
	    var reset = false;
	    
		switch (color) {
			// Dark colors
			case Color.Black:        color_id = 0;                  break;
			case Color.DarkRed:      color_id = 1;                  break;
		    case Color.DarkGreen:    color_id = 2;                  break;
			case Color.DarkYellow:   color_id = 3;                  break;
			case Color.DarkBlue:     color_id = 4;                  break;
			case Color.DarkMagenta:  color_id = 5;                  break;
			case Color.DarkCyan:     color_id = 6;                  break;
			case Color.Gray:         color_id = 7;                  break;

			// Light colors
			case Color.DarkGray:    color_id = 0; light = true;     break;
			case Color.Red:         color_id = 1; light = true;     break;
		    case Color.Green:       color_id = 2; light = true;     break;
			case Color.Yellow:      color_id = 3; light = true;     break;
			case Color.Blue:        color_id = 4; light = true;     break;
			case Color.Magenta:     color_id = 5; light = true;     break;
			case Color.Cyan:        color_id = 6; light = true;     break;
			case Color.White:       color_id = 7; light = true;     break;
			
			// Reset sequence
			case Color.Reset:       reset = true;                   break;
		}
		
		if(reset)
		    return "\x001b[0m";	
		    
		int code = color_id + (foreground ? 30 : 40) + (light ? 60 : 0);
		return "\x001b["+code.to_string()+"m";
	}
	
	private static void color(Color foreground, Color? background = null){
	    stdout.printf(get_color_code(foreground, true));
	    if(background != null){
	        stdout.printf(get_color_code(background, false));
	    }
	}
	
	private static void reset(){
	    stdout.printf(get_color_code(Color.Reset, true));
	}
	
	protected static void prelude(Level level){
	    string name = "";
	
		switch (level) {
		    case Level.FATAL:
		        color(Color.Red, Color.White);
		        name = "Fatal";
			    break;
		    case Level.ERROR:
		        color(Color.Yellow);
		        name = "Error";
		        break;
		    case Level.WARN:
		        color(Color.Yellow);
		        name = "Warn";
			    break;
		    case Level.NOTIFY:
		        color(Color.DarkMagenta);
		        name = "Notify";
			    break;
		    case Level.INFO:
		        color(Color.Blue);
		        name = "Info";
			    break;
		    case Level.DEBUG:
		        color(Color.Green);
		        name = "Debug";
			    break;
		    case Level.UNDEFINED:
		        color(Color.Black, Color.DarkYellow);
		        name = "undefined";
			    break;			    
		}
		
		stdout.printf ("[%9s]", name);
		reset();
		
		stdout.printf(" ");
	}
	
	private static bool should_log(Level level){
	    switch (level) {
		    case Level.FATAL:
		        return true;
		    case Level.ERROR:
		        return true;
		    case Level.WARN:
		        return true;
		    case Level.NOTIFY:
		        return true;
		    case Level.INFO:
		        return true;
		    case Level.DEBUG:
		        return true;
		    case Level.UNDEFINED:
		        return true;	    
		}
	}
    
    public static void printf(Level lvl, string str, ...){
        if(!should_log(lvl))
            return;
    
        prelude(lvl);
    
        var args = va_list();
        stdout.vprintf( str, args );
    }
    
    public static void print(Level lvl, string str, ...){
        if(!should_log(lvl))
            return;
    
        prelude(lvl);    
        
        var args = va_list();
        stdout.vprintf( str, args );
    }
    
    public static void println(Level lvl, string str, ...){
        if(!should_log(lvl))
            return;
    
        prelude(lvl);

        var args = va_list();
        stdout.vprintf( str, args );
        
        stdout.printf("\n");
    }
}
