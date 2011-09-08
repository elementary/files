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

#ifndef _GOF_ABSTRACT_SLOT_H
#define _GOF_ABSTRACT_SLOT_H

#include <gtk/gtk.h>

G_BEGIN_DECLS

#define GOF_TYPE_ABSTRACT_SLOT gof_abstract_slot_get_type()
#define GOF_ABSTRACT_SLOT(obj)  (G_TYPE_CHECK_INSTANCE_CAST ((obj), GOF_TYPE_ABSTRACT_SLOT, GOFAbstractSlot))
#define GOF_ABSTRACT_SLOT_CLASS(klass) (G_TYPE_CHECK_CLASS_CAST ((klass), GOF_TYPE_ABSTRACT_SLOT, GOFAbstractSlotClass))
#define GOF_IS_ABSTRACT_SLOT(obj) (G_TYPE_CHECK_INSTANCE_TYPE ((obj), GOF_TYPE_ABSTRACT_SLOT))
#define GOF_IS_ABSTRACT_SLOT_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), GOF_TYPE_ABSTRACT_SLOT))
#define GOF_ABSTRACT_SLOT_GET_CLASS(obj) (G_TYPE_INSTANCE_GET_CLASS ((obj), GOF_TYPE_ABSTRACT_SLOT, GOFAbstractSlotClass))

typedef struct _GOFAbstractSlot GOFAbstractSlot;
typedef struct _GOFAbstractSlotClass GOFAbstractSlotClass;

struct _GOFAbstractSlot
{
    GObject parent;

    GtkWidget* extra_location_widgets;
};

struct _GOFAbstractSlotClass
{
  GObjectClass parent_class;
};

GType gof_abstract_slot_get_type (void) G_GNUC_CONST;

GOFAbstractSlot *gof_abstract_slot_new (void);
void            gof_abstract_slot_add_extra_widget (GOFAbstractSlot* slot, GtkWidget* widget);

G_END_DECLS

#endif /* _GOF_ABSTRACT_SLOT_H */
