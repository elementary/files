#include "gof-abstract-slot.h"

G_DEFINE_ABSTRACT_TYPE (GOFAbstractSlot, gof_abstract_slot, G_TYPE_OBJECT)

#define ABSTRACTSLOT_PRIVATE(o) \
  (G_TYPE_INSTANCE_GET_PRIVATE ((o), GOF_TYPE_ABSTRACT_SLOT, GOFAbstractSlotPrivate))

struct _GOFAbstractSlotPrivate
{
};


/**
 * Add a widget in the top part of the slot.
 **/
void gof_abstract_window_slot_add_extra_widget (GOFAbstractSlot* slot, GtkWidget* widget)
{
    gtk_box_pack_start(slot->extra_location_widgets, widget, FALSE, FALSE, 0);
    gtk_widget_show_all(slot->extra_location_widgets);
}

static void
gof_abstract_slot_class_init (GOFAbstractSlotClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);
}

static void
gof_abstract_slot_init (GOFAbstractSlot *self)
{
  self->priv = ABSTRACTSLOT_PRIVATE (self);
}
