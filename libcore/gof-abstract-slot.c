/*
 * Copyright (C) 2011, Lucas Baudin <xapantu@gmail.com>
 *
 * Marlin is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * Marlin is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 */

/*
 * The AbstractSlot may be used by the plugins. They are needed because GOFWindowSlot
 * are in src (ok, they shouldn't, but it would require much work to move them, FIXME).
 **/

#include "gof-abstract-slot.h"

G_DEFINE_ABSTRACT_TYPE (GOFAbstractSlot, gof_abstract_slot, G_TYPE_OBJECT)


/**
 * Add a widget in the top part of the slot.
 **/
void gof_abstract_slot_add_extra_widget (GOFAbstractSlot* slot, GtkWidget* widget)
{
    gtk_box_pack_start(GTK_BOX (slot->extra_location_widgets), widget, FALSE, FALSE, 0);
    gtk_widget_show_all(slot->extra_location_widgets);
}

static void
gof_abstract_slot_class_init (GOFAbstractSlotClass *klass)
{
}

static void
gof_abstract_slot_init (GOFAbstractSlot *self)
{
}
