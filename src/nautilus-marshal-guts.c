#include	"nautilus-marshal.h"

#ifdef G_ENABLE_DEBUG
#define g_marshal_value_peek_boolean(v)  g_value_get_boolean (v)
#define g_marshal_value_peek_char(v)     g_value_get_char (v)
#define g_marshal_value_peek_uchar(v)    g_value_get_uchar (v)
#define g_marshal_value_peek_int(v)      g_value_get_int (v)
#define g_marshal_value_peek_uint(v)     g_value_get_uint (v)
#define g_marshal_value_peek_long(v)     g_value_get_long (v)
#define g_marshal_value_peek_ulong(v)    g_value_get_ulong (v)
#define g_marshal_value_peek_int64(v)    g_value_get_int64 (v)
#define g_marshal_value_peek_uint64(v)   g_value_get_uint64 (v)
#define g_marshal_value_peek_enum(v)     g_value_get_enum (v)
#define g_marshal_value_peek_flags(v)    g_value_get_flags (v)
#define g_marshal_value_peek_float(v)    g_value_get_float (v)
#define g_marshal_value_peek_double(v)   g_value_get_double (v)
#define g_marshal_value_peek_string(v)   (char*) g_value_get_string (v)
#define g_marshal_value_peek_param(v)    g_value_get_param (v)
#define g_marshal_value_peek_boxed(v)    g_value_get_boxed (v)
#define g_marshal_value_peek_pointer(v)  g_value_get_pointer (v)
#define g_marshal_value_peek_object(v)   g_value_get_object (v)
#define g_marshal_value_peek_variant(v)  g_value_get_variant (v)
#else /* !G_ENABLE_DEBUG */
/* WARNING: This code accesses GValues directly, which is UNSUPPORTED API.
 *          Do not access GValues directly in your code. Instead, use the
 *          g_value_get_*() functions
 */
#define g_marshal_value_peek_boolean(v)  (v)->data[0].v_int
#define g_marshal_value_peek_char(v)     (v)->data[0].v_int
#define g_marshal_value_peek_uchar(v)    (v)->data[0].v_uint
#define g_marshal_value_peek_int(v)      (v)->data[0].v_int
#define g_marshal_value_peek_uint(v)     (v)->data[0].v_uint
#define g_marshal_value_peek_long(v)     (v)->data[0].v_long
#define g_marshal_value_peek_ulong(v)    (v)->data[0].v_ulong
#define g_marshal_value_peek_int64(v)    (v)->data[0].v_int64
#define g_marshal_value_peek_uint64(v)   (v)->data[0].v_uint64
#define g_marshal_value_peek_enum(v)     (v)->data[0].v_long
#define g_marshal_value_peek_flags(v)    (v)->data[0].v_ulong
#define g_marshal_value_peek_float(v)    (v)->data[0].v_float
#define g_marshal_value_peek_double(v)   (v)->data[0].v_double
#define g_marshal_value_peek_string(v)   (v)->data[0].v_pointer
#define g_marshal_value_peek_param(v)    (v)->data[0].v_pointer
#define g_marshal_value_peek_boxed(v)    (v)->data[0].v_pointer
#define g_marshal_value_peek_pointer(v)  (v)->data[0].v_pointer
#define g_marshal_value_peek_object(v)   (v)->data[0].v_pointer
#define g_marshal_value_peek_variant(v)  (v)->data[0].v_pointer
#endif /* !G_ENABLE_DEBUG */


/* BOOLEAN:POINTER (nautilus-marshal.list:1) */
void
nautilus_marshal_BOOLEAN__POINTER (GClosure     *closure,
                                   GValue       *return_value G_GNUC_UNUSED,
                                   guint         n_param_values,
                                   const GValue *param_values,
                                   gpointer      invocation_hint G_GNUC_UNUSED,
                                   gpointer      marshal_data)
{
    typedef gboolean (*GMarshalFunc_BOOLEAN__POINTER) (gpointer     data1,
                                                       gpointer     arg_1,
                                                       gpointer     data2);
    register GMarshalFunc_BOOLEAN__POINTER callback;
    register GCClosure *cc = (GCClosure*) closure;
    register gpointer data1, data2;
    gboolean v_return;

    g_return_if_fail (return_value != NULL);
    g_return_if_fail (n_param_values == 2);

    if (G_CCLOSURE_SWAP_DATA (closure))
    {
        data1 = closure->data;
        data2 = g_value_peek_pointer (param_values + 0);
    }
    else
    {
        data1 = g_value_peek_pointer (param_values + 0);
        data2 = closure->data;
    }
    callback = (GMarshalFunc_BOOLEAN__POINTER) (marshal_data ? marshal_data : cc->callback);

    v_return = callback (data1,
                         g_marshal_value_peek_pointer (param_values + 1),
                         data2);

    g_value_set_boolean (return_value, v_return);
}

/* BOOLEAN:VOID (nautilus-marshal.list:2) */
void
nautilus_marshal_BOOLEAN__VOID (GClosure     *closure,
                                GValue       *return_value G_GNUC_UNUSED,
                                guint         n_param_values,
                                const GValue *param_values,
                                gpointer      invocation_hint G_GNUC_UNUSED,
                                gpointer      marshal_data)
{
    typedef gboolean (*GMarshalFunc_BOOLEAN__VOID) (gpointer     data1,
                                                    gpointer     data2);
    register GMarshalFunc_BOOLEAN__VOID callback;
    register GCClosure *cc = (GCClosure*) closure;
    register gpointer data1, data2;
    gboolean v_return;

    g_return_if_fail (return_value != NULL);
    g_return_if_fail (n_param_values == 1);

    if (G_CCLOSURE_SWAP_DATA (closure))
    {
        data1 = closure->data;
        data2 = g_value_peek_pointer (param_values + 0);
    }
    else
    {
        data1 = g_value_peek_pointer (param_values + 0);
        data2 = closure->data;
    }
    callback = (GMarshalFunc_BOOLEAN__VOID) (marshal_data ? marshal_data : cc->callback);

    v_return = callback (data1,
                         data2);

    g_value_set_boolean (return_value, v_return);
}

/* INT:POINTER,BOOLEAN (nautilus-marshal.list:3) */
void
nautilus_marshal_INT__POINTER_BOOLEAN (GClosure     *closure,
                                       GValue       *return_value G_GNUC_UNUSED,
                                       guint         n_param_values,
                                       const GValue *param_values,
                                       gpointer      invocation_hint G_GNUC_UNUSED,
                                       gpointer      marshal_data)
{
    typedef gint (*GMarshalFunc_INT__POINTER_BOOLEAN) (gpointer     data1,
                                                       gpointer     arg_1,
                                                       gboolean     arg_2,
                                                       gpointer     data2);
    register GMarshalFunc_INT__POINTER_BOOLEAN callback;
    register GCClosure *cc = (GCClosure*) closure;
    register gpointer data1, data2;
    gint v_return;

    g_return_if_fail (return_value != NULL);
    g_return_if_fail (n_param_values == 3);

    if (G_CCLOSURE_SWAP_DATA (closure))
    {
        data1 = closure->data;
        data2 = g_value_peek_pointer (param_values + 0);
    }
    else
    {
        data1 = g_value_peek_pointer (param_values + 0);
        data2 = closure->data;
    }
    callback = (GMarshalFunc_INT__POINTER_BOOLEAN) (marshal_data ? marshal_data : cc->callback);

    v_return = callback (data1,
                         g_marshal_value_peek_pointer (param_values + 1),
                         g_marshal_value_peek_boolean (param_values + 2),
                         data2);

    g_value_set_int (return_value, v_return);
}

/* INT:POINTER,INT (nautilus-marshal.list:4) */
void
nautilus_marshal_INT__POINTER_INT (GClosure     *closure,
                                   GValue       *return_value G_GNUC_UNUSED,
                                   guint         n_param_values,
                                   const GValue *param_values,
                                   gpointer      invocation_hint G_GNUC_UNUSED,
                                   gpointer      marshal_data)
{
    typedef gint (*GMarshalFunc_INT__POINTER_INT) (gpointer     data1,
                                                   gpointer     arg_1,
                                                   gint         arg_2,
                                                   gpointer     data2);
    register GMarshalFunc_INT__POINTER_INT callback;
    register GCClosure *cc = (GCClosure*) closure;
    register gpointer data1, data2;
    gint v_return;

    g_return_if_fail (return_value != NULL);
    g_return_if_fail (n_param_values == 3);

    if (G_CCLOSURE_SWAP_DATA (closure))
    {
        data1 = closure->data;
        data2 = g_value_peek_pointer (param_values + 0);
    }
    else
    {
        data1 = g_value_peek_pointer (param_values + 0);
        data2 = closure->data;
    }
    callback = (GMarshalFunc_INT__POINTER_INT) (marshal_data ? marshal_data : cc->callback);

    v_return = callback (data1,
                         g_marshal_value_peek_pointer (param_values + 1),
                         g_marshal_value_peek_int (param_values + 2),
                         data2);

    g_value_set_int (return_value, v_return);
}

/* INT:POINTER,POINTER (nautilus-marshal.list:5) */
void
nautilus_marshal_INT__POINTER_POINTER (GClosure     *closure,
                                       GValue       *return_value G_GNUC_UNUSED,
                                       guint         n_param_values,
                                       const GValue *param_values,
                                       gpointer      invocation_hint G_GNUC_UNUSED,
                                       gpointer      marshal_data)
{
    typedef gint (*GMarshalFunc_INT__POINTER_POINTER) (gpointer     data1,
                                                       gpointer     arg_1,
                                                       gpointer     arg_2,
                                                       gpointer     data2);
    register GMarshalFunc_INT__POINTER_POINTER callback;
    register GCClosure *cc = (GCClosure*) closure;
    register gpointer data1, data2;
    gint v_return;

    g_return_if_fail (return_value != NULL);
    g_return_if_fail (n_param_values == 3);

    if (G_CCLOSURE_SWAP_DATA (closure))
    {
        data1 = closure->data;
        data2 = g_value_peek_pointer (param_values + 0);
    }
    else
    {
        data1 = g_value_peek_pointer (param_values + 0);
        data2 = closure->data;
    }
    callback = (GMarshalFunc_INT__POINTER_POINTER) (marshal_data ? marshal_data : cc->callback);

    v_return = callback (data1,
                         g_marshal_value_peek_pointer (param_values + 1),
                         g_marshal_value_peek_pointer (param_values + 2),
                         data2);

    g_value_set_int (return_value, v_return);
}

/* OBJECT:BOXED (nautilus-marshal.list:6) */
void
nautilus_marshal_OBJECT__BOXED (GClosure     *closure,
                                GValue       *return_value G_GNUC_UNUSED,
                                guint         n_param_values,
                                const GValue *param_values,
                                gpointer      invocation_hint G_GNUC_UNUSED,
                                gpointer      marshal_data)
{
    typedef GObject* (*GMarshalFunc_OBJECT__BOXED) (gpointer     data1,
                                                    gpointer     arg_1,
                                                    gpointer     data2);
    register GMarshalFunc_OBJECT__BOXED callback;
    register GCClosure *cc = (GCClosure*) closure;
    register gpointer data1, data2;
    GObject* v_return;

    g_return_if_fail (return_value != NULL);
    g_return_if_fail (n_param_values == 2);

    if (G_CCLOSURE_SWAP_DATA (closure))
    {
        data1 = closure->data;
        data2 = g_value_peek_pointer (param_values + 0);
    }
    else
    {
        data1 = g_value_peek_pointer (param_values + 0);
        data2 = closure->data;
    }
    callback = (GMarshalFunc_OBJECT__BOXED) (marshal_data ? marshal_data : cc->callback);

    v_return = callback (data1,
                         g_marshal_value_peek_boxed (param_values + 1),
                         data2);

    g_value_take_object (return_value, v_return);
}

/* POINTER:VOID (nautilus-marshal.list:7) */
void
nautilus_marshal_POINTER__VOID (GClosure     *closure,
                                GValue       *return_value G_GNUC_UNUSED,
                                guint         n_param_values,
                                const GValue *param_values,
                                gpointer      invocation_hint G_GNUC_UNUSED,
                                gpointer      marshal_data)
{
    typedef gpointer (*GMarshalFunc_POINTER__VOID) (gpointer     data1,
                                                    gpointer     data2);
    register GMarshalFunc_POINTER__VOID callback;
    register GCClosure *cc = (GCClosure*) closure;
    register gpointer data1, data2;
    gpointer v_return;

    g_return_if_fail (return_value != NULL);
    g_return_if_fail (n_param_values == 1);

    if (G_CCLOSURE_SWAP_DATA (closure))
    {
        data1 = closure->data;
        data2 = g_value_peek_pointer (param_values + 0);
    }
    else
    {
        data1 = g_value_peek_pointer (param_values + 0);
        data2 = closure->data;
    }
    callback = (GMarshalFunc_POINTER__VOID) (marshal_data ? marshal_data : cc->callback);

    v_return = callback (data1,
                         data2);

    g_value_set_pointer (return_value, v_return);
}

/* STRING:VOID (nautilus-marshal.list:8) */
void
nautilus_marshal_STRING__VOID (GClosure     *closure,
                               GValue       *return_value G_GNUC_UNUSED,
                               guint         n_param_values,
                               const GValue *param_values,
                               gpointer      invocation_hint G_GNUC_UNUSED,
                               gpointer      marshal_data)
{
    typedef gchar* (*GMarshalFunc_STRING__VOID) (gpointer     data1,
                                                 gpointer     data2);
    register GMarshalFunc_STRING__VOID callback;
    register GCClosure *cc = (GCClosure*) closure;
    register gpointer data1, data2;
    gchar* v_return;

    g_return_if_fail (return_value != NULL);
    g_return_if_fail (n_param_values == 1);

    if (G_CCLOSURE_SWAP_DATA (closure))
    {
        data1 = closure->data;
        data2 = g_value_peek_pointer (param_values + 0);
    }
    else
    {
        data1 = g_value_peek_pointer (param_values + 0);
        data2 = closure->data;
    }
    callback = (GMarshalFunc_STRING__VOID) (marshal_data ? marshal_data : cc->callback);

    v_return = callback (data1,
                         data2);

    g_value_take_string (return_value, v_return);
}

/* VOID:DOUBLE (nautilus-marshal.list:9) */

/* VOID:INT,BOOLEAN,BOOLEAN,BOOLEAN,BOOLEAN (nautilus-marshal.list:10) */
void
nautilus_marshal_VOID__INT_BOOLEAN_BOOLEAN_BOOLEAN_BOOLEAN (GClosure     *closure,
                                                            GValue       *return_value G_GNUC_UNUSED,
                                                            guint         n_param_values,
                                                            const GValue *param_values,
                                                            gpointer      invocation_hint G_GNUC_UNUSED,
                                                            gpointer      marshal_data)
{
    typedef void (*GMarshalFunc_VOID__INT_BOOLEAN_BOOLEAN_BOOLEAN_BOOLEAN) (gpointer     data1,
                                                                            gint         arg_1,
                                                                            gboolean     arg_2,
                                                                            gboolean     arg_3,
                                                                            gboolean     arg_4,
                                                                            gboolean     arg_5,
                                                                            gpointer     data2);
    register GMarshalFunc_VOID__INT_BOOLEAN_BOOLEAN_BOOLEAN_BOOLEAN callback;
    register GCClosure *cc = (GCClosure*) closure;
    register gpointer data1, data2;

    g_return_if_fail (n_param_values == 6);

    if (G_CCLOSURE_SWAP_DATA (closure))
    {
        data1 = closure->data;
        data2 = g_value_peek_pointer (param_values + 0);
    }
    else
    {
        data1 = g_value_peek_pointer (param_values + 0);
        data2 = closure->data;
    }
    callback = (GMarshalFunc_VOID__INT_BOOLEAN_BOOLEAN_BOOLEAN_BOOLEAN) (marshal_data ? marshal_data : cc->callback);

    callback (data1,
              g_marshal_value_peek_int (param_values + 1),
              g_marshal_value_peek_boolean (param_values + 2),
              g_marshal_value_peek_boolean (param_values + 3),
              g_marshal_value_peek_boolean (param_values + 4),
              g_marshal_value_peek_boolean (param_values + 5),
              data2);
}

/* VOID:INT,STRING (nautilus-marshal.list:11) */
void
nautilus_marshal_VOID__INT_STRING (GClosure     *closure,
                                   GValue       *return_value G_GNUC_UNUSED,
                                   guint         n_param_values,
                                   const GValue *param_values,
                                   gpointer      invocation_hint G_GNUC_UNUSED,
                                   gpointer      marshal_data)
{
    typedef void (*GMarshalFunc_VOID__INT_STRING) (gpointer     data1,
                                                   gint         arg_1,
                                                   gpointer     arg_2,
                                                   gpointer     data2);
    register GMarshalFunc_VOID__INT_STRING callback;
    register GCClosure *cc = (GCClosure*) closure;
    register gpointer data1, data2;

    g_return_if_fail (n_param_values == 3);

    if (G_CCLOSURE_SWAP_DATA (closure))
    {
        data1 = closure->data;
        data2 = g_value_peek_pointer (param_values + 0);
    }
    else
    {
        data1 = g_value_peek_pointer (param_values + 0);
        data2 = closure->data;
    }
    callback = (GMarshalFunc_VOID__INT_STRING) (marshal_data ? marshal_data : cc->callback);

    callback (data1,
              g_marshal_value_peek_int (param_values + 1),
              g_marshal_value_peek_string (param_values + 2),
              data2);
}

/* VOID:OBJECT,BOOLEAN (nautilus-marshal.list:12) */
void
nautilus_marshal_VOID__OBJECT_BOOLEAN (GClosure     *closure,
                                       GValue       *return_value G_GNUC_UNUSED,
                                       guint         n_param_values,
                                       const GValue *param_values,
                                       gpointer      invocation_hint G_GNUC_UNUSED,
                                       gpointer      marshal_data)
{
    typedef void (*GMarshalFunc_VOID__OBJECT_BOOLEAN) (gpointer     data1,
                                                       gpointer     arg_1,
                                                       gboolean     arg_2,
                                                       gpointer     data2);
    register GMarshalFunc_VOID__OBJECT_BOOLEAN callback;
    register GCClosure *cc = (GCClosure*) closure;
    register gpointer data1, data2;

    g_return_if_fail (n_param_values == 3);

    if (G_CCLOSURE_SWAP_DATA (closure))
    {
        data1 = closure->data;
        data2 = g_value_peek_pointer (param_values + 0);
    }
    else
    {
        data1 = g_value_peek_pointer (param_values + 0);
        data2 = closure->data;
    }
    callback = (GMarshalFunc_VOID__OBJECT_BOOLEAN) (marshal_data ? marshal_data : cc->callback);

    callback (data1,
              g_marshal_value_peek_object (param_values + 1),
              g_marshal_value_peek_boolean (param_values + 2),
              data2);
}

/* VOID:OBJECT,OBJECT (nautilus-marshal.list:13) */
void
nautilus_marshal_VOID__OBJECT_OBJECT (GClosure     *closure,
                                      GValue       *return_value G_GNUC_UNUSED,
                                      guint         n_param_values,
                                      const GValue *param_values,
                                      gpointer      invocation_hint G_GNUC_UNUSED,
                                      gpointer      marshal_data)
{
    typedef void (*GMarshalFunc_VOID__OBJECT_OBJECT) (gpointer     data1,
                                                      gpointer     arg_1,
                                                      gpointer     arg_2,
                                                      gpointer     data2);
    register GMarshalFunc_VOID__OBJECT_OBJECT callback;
    register GCClosure *cc = (GCClosure*) closure;
    register gpointer data1, data2;

    g_return_if_fail (n_param_values == 3);

    if (G_CCLOSURE_SWAP_DATA (closure))
    {
        data1 = closure->data;
        data2 = g_value_peek_pointer (param_values + 0);
    }
    else
    {
        data1 = g_value_peek_pointer (param_values + 0);
        data2 = closure->data;
    }
    callback = (GMarshalFunc_VOID__OBJECT_OBJECT) (marshal_data ? marshal_data : cc->callback);

    callback (data1,
              g_marshal_value_peek_object (param_values + 1),
              g_marshal_value_peek_object (param_values + 2),
              data2);
}

/* VOID:POINTER,ENUM (nautilus-marshal.list:14) */
void
nautilus_marshal_VOID__POINTER_ENUM (GClosure     *closure,
                                     GValue       *return_value G_GNUC_UNUSED,
                                     guint         n_param_values,
                                     const GValue *param_values,
                                     gpointer      invocation_hint G_GNUC_UNUSED,
                                     gpointer      marshal_data)
{
    typedef void (*GMarshalFunc_VOID__POINTER_ENUM) (gpointer     data1,
                                                     gpointer     arg_1,
                                                     gint         arg_2,
                                                     gpointer     data2);
    register GMarshalFunc_VOID__POINTER_ENUM callback;
    register GCClosure *cc = (GCClosure*) closure;
    register gpointer data1, data2;

    g_return_if_fail (n_param_values == 3);

    if (G_CCLOSURE_SWAP_DATA (closure))
    {
        data1 = closure->data;
        data2 = g_value_peek_pointer (param_values + 0);
    }
    else
    {
        data1 = g_value_peek_pointer (param_values + 0);
        data2 = closure->data;
    }
    callback = (GMarshalFunc_VOID__POINTER_ENUM) (marshal_data ? marshal_data : cc->callback);

    callback (data1,
              g_marshal_value_peek_pointer (param_values + 1),
              g_marshal_value_peek_enum (param_values + 2),
              data2);
}

/* VOID:POINTER,POINTER (nautilus-marshal.list:15) */
void
nautilus_marshal_VOID__POINTER_POINTER (GClosure     *closure,
                                        GValue       *return_value G_GNUC_UNUSED,
                                        guint         n_param_values,
                                        const GValue *param_values,
                                        gpointer      invocation_hint G_GNUC_UNUSED,
                                        gpointer      marshal_data)
{
    typedef void (*GMarshalFunc_VOID__POINTER_POINTER) (gpointer     data1,
                                                        gpointer     arg_1,
                                                        gpointer     arg_2,
                                                        gpointer     data2);
    register GMarshalFunc_VOID__POINTER_POINTER callback;
    register GCClosure *cc = (GCClosure*) closure;
    register gpointer data1, data2;

    g_return_if_fail (n_param_values == 3);

    if (G_CCLOSURE_SWAP_DATA (closure))
    {
        data1 = closure->data;
        data2 = g_value_peek_pointer (param_values + 0);
    }
    else
    {
        data1 = g_value_peek_pointer (param_values + 0);
        data2 = closure->data;
    }
    callback = (GMarshalFunc_VOID__POINTER_POINTER) (marshal_data ? marshal_data : cc->callback);

    callback (data1,
              g_marshal_value_peek_pointer (param_values + 1),
              g_marshal_value_peek_pointer (param_values + 2),
              data2);
}

/* VOID:POINTER,POINTER (nautilus-marshal.list:16) */

/* VOID:POINTER,POINTER,POINTER,ENUM,INT,INT (nautilus-marshal.list:17) */
void
nautilus_marshal_VOID__POINTER_POINTER_POINTER_ENUM_INT_INT (GClosure     *closure,
                                                             GValue       *return_value G_GNUC_UNUSED,
                                                             guint         n_param_values,
                                                             const GValue *param_values,
                                                             gpointer      invocation_hint G_GNUC_UNUSED,
                                                             gpointer      marshal_data)
{
    typedef void (*GMarshalFunc_VOID__POINTER_POINTER_POINTER_ENUM_INT_INT) (gpointer     data1,
                                                                             gpointer     arg_1,
                                                                             gpointer     arg_2,
                                                                             gpointer     arg_3,
                                                                             gint         arg_4,
                                                                             gint         arg_5,
                                                                             gint         arg_6,
                                                                             gpointer     data2);
    register GMarshalFunc_VOID__POINTER_POINTER_POINTER_ENUM_INT_INT callback;
    register GCClosure *cc = (GCClosure*) closure;
    register gpointer data1, data2;

    g_return_if_fail (n_param_values == 7);

    if (G_CCLOSURE_SWAP_DATA (closure))
    {
        data1 = closure->data;
        data2 = g_value_peek_pointer (param_values + 0);
    }
    else
    {
        data1 = g_value_peek_pointer (param_values + 0);
        data2 = closure->data;
    }
    callback = (GMarshalFunc_VOID__POINTER_POINTER_POINTER_ENUM_INT_INT) (marshal_data ? marshal_data : cc->callback);

    callback (data1,
              g_marshal_value_peek_pointer (param_values + 1),
              g_marshal_value_peek_pointer (param_values + 2),
              g_marshal_value_peek_pointer (param_values + 3),
              g_marshal_value_peek_enum (param_values + 4),
              g_marshal_value_peek_int (param_values + 5),
              g_marshal_value_peek_int (param_values + 6),
              data2);
}

/* VOID:POINTER,STRING (nautilus-marshal.list:18) */
void
nautilus_marshal_VOID__POINTER_STRING (GClosure     *closure,
                                       GValue       *return_value G_GNUC_UNUSED,
                                       guint         n_param_values,
                                       const GValue *param_values,
                                       gpointer      invocation_hint G_GNUC_UNUSED,
                                       gpointer      marshal_data)
{
    typedef void (*GMarshalFunc_VOID__POINTER_STRING) (gpointer     data1,
                                                       gpointer     arg_1,
                                                       gpointer     arg_2,
                                                       gpointer     data2);
    register GMarshalFunc_VOID__POINTER_STRING callback;
    register GCClosure *cc = (GCClosure*) closure;
    register gpointer data1, data2;

    g_return_if_fail (n_param_values == 3);

    if (G_CCLOSURE_SWAP_DATA (closure))
    {
        data1 = closure->data;
        data2 = g_value_peek_pointer (param_values + 0);
    }
    else
    {
        data1 = g_value_peek_pointer (param_values + 0);
        data2 = closure->data;
    }
    callback = (GMarshalFunc_VOID__POINTER_STRING) (marshal_data ? marshal_data : cc->callback);

    callback (data1,
              g_marshal_value_peek_pointer (param_values + 1),
              g_marshal_value_peek_string (param_values + 2),
              data2);
}

/* VOID:POINTER,STRING,ENUM,INT,INT (nautilus-marshal.list:19) */
void
nautilus_marshal_VOID__POINTER_STRING_ENUM_INT_INT (GClosure     *closure,
                                                    GValue       *return_value G_GNUC_UNUSED,
                                                    guint         n_param_values,
                                                    const GValue *param_values,
                                                    gpointer      invocation_hint G_GNUC_UNUSED,
                                                    gpointer      marshal_data)
{
    typedef void (*GMarshalFunc_VOID__POINTER_STRING_ENUM_INT_INT) (gpointer     data1,
                                                                    gpointer     arg_1,
                                                                    gpointer     arg_2,
                                                                    gint         arg_3,
                                                                    gint         arg_4,
                                                                    gint         arg_5,
                                                                    gpointer     data2);
    register GMarshalFunc_VOID__POINTER_STRING_ENUM_INT_INT callback;
    register GCClosure *cc = (GCClosure*) closure;
    register gpointer data1, data2;

    g_return_if_fail (n_param_values == 6);

    if (G_CCLOSURE_SWAP_DATA (closure))
    {
        data1 = closure->data;
        data2 = g_value_peek_pointer (param_values + 0);
    }
    else
    {
        data1 = g_value_peek_pointer (param_values + 0);
        data2 = closure->data;
    }
    callback = (GMarshalFunc_VOID__POINTER_STRING_ENUM_INT_INT) (marshal_data ? marshal_data : cc->callback);

    callback (data1,
              g_marshal_value_peek_pointer (param_values + 1),
              g_marshal_value_peek_string (param_values + 2),
              g_marshal_value_peek_enum (param_values + 3),
              g_marshal_value_peek_int (param_values + 4),
              g_marshal_value_peek_int (param_values + 5),
              data2);
}

/* VOID:STRING,STRING,ENUM,INT,INT (nautilus-marshal.list:20) */
void
nautilus_marshal_VOID__STRING_STRING_ENUM_INT_INT (GClosure     *closure,
                                                   GValue       *return_value G_GNUC_UNUSED,
                                                   guint         n_param_values,
                                                   const GValue *param_values,
                                                   gpointer      invocation_hint G_GNUC_UNUSED,
                                                   gpointer      marshal_data)
{
    typedef void (*GMarshalFunc_VOID__STRING_STRING_ENUM_INT_INT) (gpointer     data1,
                                                                   gpointer     arg_1,
                                                                   gpointer     arg_2,
                                                                   gint         arg_3,
                                                                   gint         arg_4,
                                                                   gint         arg_5,
                                                                   gpointer     data2);
    register GMarshalFunc_VOID__STRING_STRING_ENUM_INT_INT callback;
    register GCClosure *cc = (GCClosure*) closure;
    register gpointer data1, data2;

    g_return_if_fail (n_param_values == 6);

    if (G_CCLOSURE_SWAP_DATA (closure))
    {
        data1 = closure->data;
        data2 = g_value_peek_pointer (param_values + 0);
    }
    else
    {
        data1 = g_value_peek_pointer (param_values + 0);
        data2 = closure->data;
    }
    callback = (GMarshalFunc_VOID__STRING_STRING_ENUM_INT_INT) (marshal_data ? marshal_data : cc->callback);

    callback (data1,
              g_marshal_value_peek_string (param_values + 1),
              g_marshal_value_peek_string (param_values + 2),
              g_marshal_value_peek_enum (param_values + 3),
              g_marshal_value_peek_int (param_values + 4),
              g_marshal_value_peek_int (param_values + 5),
              data2);
}

/* VOID:STRING,ENUM,INT,INT (nautilus-marshal.list:21) */
void
nautilus_marshal_VOID__STRING_ENUM_INT_INT (GClosure     *closure,
                                            GValue       *return_value G_GNUC_UNUSED,
                                            guint         n_param_values,
                                            const GValue *param_values,
                                            gpointer      invocation_hint G_GNUC_UNUSED,
                                            gpointer      marshal_data)
{
    typedef void (*GMarshalFunc_VOID__STRING_ENUM_INT_INT) (gpointer     data1,
                                                            gpointer     arg_1,
                                                            gint         arg_2,
                                                            gint         arg_3,
                                                            gint         arg_4,
                                                            gpointer     data2);
    register GMarshalFunc_VOID__STRING_ENUM_INT_INT callback;
    register GCClosure *cc = (GCClosure*) closure;
    register gpointer data1, data2;

    g_return_if_fail (n_param_values == 5);

    if (G_CCLOSURE_SWAP_DATA (closure))
    {
        data1 = closure->data;
        data2 = g_value_peek_pointer (param_values + 0);
    }
    else
    {
        data1 = g_value_peek_pointer (param_values + 0);
        data2 = closure->data;
    }
    callback = (GMarshalFunc_VOID__STRING_ENUM_INT_INT) (marshal_data ? marshal_data : cc->callback);

    callback (data1,
              g_marshal_value_peek_string (param_values + 1),
              g_marshal_value_peek_enum (param_values + 2),
              g_marshal_value_peek_int (param_values + 3),
              g_marshal_value_peek_int (param_values + 4),
              data2);
}

/* VOID:STRING,STRING (nautilus-marshal.list:22) */
void
nautilus_marshal_VOID__STRING_STRING (GClosure     *closure,
                                      GValue       *return_value G_GNUC_UNUSED,
                                      guint         n_param_values,
                                      const GValue *param_values,
                                      gpointer      invocation_hint G_GNUC_UNUSED,
                                      gpointer      marshal_data)
{
    typedef void (*GMarshalFunc_VOID__STRING_STRING) (gpointer     data1,
                                                      gpointer     arg_1,
                                                      gpointer     arg_2,
                                                      gpointer     data2);
    register GMarshalFunc_VOID__STRING_STRING callback;
    register GCClosure *cc = (GCClosure*) closure;
    register gpointer data1, data2;

    g_return_if_fail (n_param_values == 3);

    if (G_CCLOSURE_SWAP_DATA (closure))
    {
        data1 = closure->data;
        data2 = g_value_peek_pointer (param_values + 0);
    }
    else
    {
        data1 = g_value_peek_pointer (param_values + 0);
        data2 = closure->data;
    }
    callback = (GMarshalFunc_VOID__STRING_STRING) (marshal_data ? marshal_data : cc->callback);

    callback (data1,
              g_marshal_value_peek_string (param_values + 1),
              g_marshal_value_peek_string (param_values + 2),
              data2);
}

/* VOID:POINTER,INT,STRING,STRING,ENUM,INT,INT (nautilus-marshal.list:23) */
void
nautilus_marshal_VOID__POINTER_INT_STRING_STRING_ENUM_INT_INT (GClosure     *closure,
                                                               GValue       *return_value G_GNUC_UNUSED,
                                                               guint         n_param_values,
                                                               const GValue *param_values,
                                                               gpointer      invocation_hint G_GNUC_UNUSED,
                                                               gpointer      marshal_data)
{
    typedef void (*GMarshalFunc_VOID__POINTER_INT_STRING_STRING_ENUM_INT_INT) (gpointer     data1,
                                                                               gpointer     arg_1,
                                                                               gint         arg_2,
                                                                               gpointer     arg_3,
                                                                               gpointer     arg_4,
                                                                               gint         arg_5,
                                                                               gint         arg_6,
                                                                               gint         arg_7,
                                                                               gpointer     data2);
    register GMarshalFunc_VOID__POINTER_INT_STRING_STRING_ENUM_INT_INT callback;
    register GCClosure *cc = (GCClosure*) closure;
    register gpointer data1, data2;

    g_return_if_fail (n_param_values == 8);

    if (G_CCLOSURE_SWAP_DATA (closure))
    {
        data1 = closure->data;
        data2 = g_value_peek_pointer (param_values + 0);
    }
    else
    {
        data1 = g_value_peek_pointer (param_values + 0);
        data2 = closure->data;
    }
    callback = (GMarshalFunc_VOID__POINTER_INT_STRING_STRING_ENUM_INT_INT) (marshal_data ? marshal_data : cc->callback);

    callback (data1,
              g_marshal_value_peek_pointer (param_values + 1),
              g_marshal_value_peek_int (param_values + 2),
              g_marshal_value_peek_string (param_values + 3),
              g_marshal_value_peek_string (param_values + 4),
              g_marshal_value_peek_enum (param_values + 5),
              g_marshal_value_peek_int (param_values + 6),
              g_marshal_value_peek_int (param_values + 7),
              data2);
}

