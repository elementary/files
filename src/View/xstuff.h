#ifndef __XSTUFF_H__
#define __XSTUFF_H__

#include <gdk/gdk.h>
#include <gtk/gtk.h>

void xstuff_zoom_animate                (GtkWidget        *widget,
					 GdkPixbuf        *pixbuf,
					 GdkRectangle     *opt_src_rect);

#endif /* __XSTUFF_H__ */
