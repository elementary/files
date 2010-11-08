#ifndef __nautilus_marshal_MARSHAL_H__
#define __nautilus_marshal_MARSHAL_H__

#include	<glib-object.h>

G_BEGIN_DECLS

/* BOOLEAN:POINTER (nautilus-marshal.list:1) */
extern void nautilus_marshal_BOOLEAN__POINTER (GClosure     *closure,
                                               GValue       *return_value,
                                               guint         n_param_values,
                                               const GValue *param_values,
                                               gpointer      invocation_hint,
                                               gpointer      marshal_data);

/* BOOLEAN:VOID (nautilus-marshal.list:2) */
extern void nautilus_marshal_BOOLEAN__VOID (GClosure     *closure,
                                            GValue       *return_value,
                                            guint         n_param_values,
                                            const GValue *param_values,
                                            gpointer      invocation_hint,
                                            gpointer      marshal_data);

/* INT:POINTER,BOOLEAN (nautilus-marshal.list:3) */
extern void nautilus_marshal_INT__POINTER_BOOLEAN (GClosure     *closure,
                                                   GValue       *return_value,
                                                   guint         n_param_values,
                                                   const GValue *param_values,
                                                   gpointer      invocation_hint,
                                                   gpointer      marshal_data);

/* INT:POINTER,INT (nautilus-marshal.list:4) */
extern void nautilus_marshal_INT__POINTER_INT (GClosure     *closure,
                                               GValue       *return_value,
                                               guint         n_param_values,
                                               const GValue *param_values,
                                               gpointer      invocation_hint,
                                               gpointer      marshal_data);

/* INT:POINTER,POINTER (nautilus-marshal.list:5) */
extern void nautilus_marshal_INT__POINTER_POINTER (GClosure     *closure,
                                                   GValue       *return_value,
                                                   guint         n_param_values,
                                                   const GValue *param_values,
                                                   gpointer      invocation_hint,
                                                   gpointer      marshal_data);

/* OBJECT:BOXED (nautilus-marshal.list:6) */
extern void nautilus_marshal_OBJECT__BOXED (GClosure     *closure,
                                            GValue       *return_value,
                                            guint         n_param_values,
                                            const GValue *param_values,
                                            gpointer      invocation_hint,
                                            gpointer      marshal_data);

/* POINTER:VOID (nautilus-marshal.list:7) */
extern void nautilus_marshal_POINTER__VOID (GClosure     *closure,
                                            GValue       *return_value,
                                            guint         n_param_values,
                                            const GValue *param_values,
                                            gpointer      invocation_hint,
                                            gpointer      marshal_data);

/* STRING:VOID (nautilus-marshal.list:8) */
extern void nautilus_marshal_STRING__VOID (GClosure     *closure,
                                           GValue       *return_value,
                                           guint         n_param_values,
                                           const GValue *param_values,
                                           gpointer      invocation_hint,
                                           gpointer      marshal_data);

/* VOID:DOUBLE (nautilus-marshal.list:9) */
#define nautilus_marshal_VOID__DOUBLE	g_cclosure_marshal_VOID__DOUBLE

/* VOID:INT,BOOLEAN,BOOLEAN,BOOLEAN,BOOLEAN (nautilus-marshal.list:10) */
extern void nautilus_marshal_VOID__INT_BOOLEAN_BOOLEAN_BOOLEAN_BOOLEAN (GClosure     *closure,
                                                                        GValue       *return_value,
                                                                        guint         n_param_values,
                                                                        const GValue *param_values,
                                                                        gpointer      invocation_hint,
                                                                        gpointer      marshal_data);

/* VOID:INT,STRING (nautilus-marshal.list:11) */
extern void nautilus_marshal_VOID__INT_STRING (GClosure     *closure,
                                               GValue       *return_value,
                                               guint         n_param_values,
                                               const GValue *param_values,
                                               gpointer      invocation_hint,
                                               gpointer      marshal_data);

/* VOID:OBJECT,BOOLEAN (nautilus-marshal.list:12) */
extern void nautilus_marshal_VOID__OBJECT_BOOLEAN (GClosure     *closure,
                                                   GValue       *return_value,
                                                   guint         n_param_values,
                                                   const GValue *param_values,
                                                   gpointer      invocation_hint,
                                                   gpointer      marshal_data);

/* VOID:OBJECT,OBJECT (nautilus-marshal.list:13) */
extern void nautilus_marshal_VOID__OBJECT_OBJECT (GClosure     *closure,
                                                  GValue       *return_value,
                                                  guint         n_param_values,
                                                  const GValue *param_values,
                                                  gpointer      invocation_hint,
                                                  gpointer      marshal_data);

/* VOID:POINTER,ENUM (nautilus-marshal.list:14) */
extern void nautilus_marshal_VOID__POINTER_ENUM (GClosure     *closure,
                                                 GValue       *return_value,
                                                 guint         n_param_values,
                                                 const GValue *param_values,
                                                 gpointer      invocation_hint,
                                                 gpointer      marshal_data);

/* VOID:POINTER,POINTER (nautilus-marshal.list:15) */
extern void nautilus_marshal_VOID__POINTER_POINTER (GClosure     *closure,
                                                    GValue       *return_value,
                                                    guint         n_param_values,
                                                    const GValue *param_values,
                                                    gpointer      invocation_hint,
                                                    gpointer      marshal_data);

/* VOID:POINTER,POINTER (nautilus-marshal.list:16) */

/* VOID:POINTER,POINTER,POINTER,ENUM,INT,INT (nautilus-marshal.list:17) */
extern void nautilus_marshal_VOID__POINTER_POINTER_POINTER_ENUM_INT_INT (GClosure     *closure,
                                                                         GValue       *return_value,
                                                                         guint         n_param_values,
                                                                         const GValue *param_values,
                                                                         gpointer      invocation_hint,
                                                                         gpointer      marshal_data);

/* VOID:POINTER,STRING (nautilus-marshal.list:18) */
extern void nautilus_marshal_VOID__POINTER_STRING (GClosure     *closure,
                                                   GValue       *return_value,
                                                   guint         n_param_values,
                                                   const GValue *param_values,
                                                   gpointer      invocation_hint,
                                                   gpointer      marshal_data);

/* VOID:POINTER,STRING,ENUM,INT,INT (nautilus-marshal.list:19) */
extern void nautilus_marshal_VOID__POINTER_STRING_ENUM_INT_INT (GClosure     *closure,
                                                                GValue       *return_value,
                                                                guint         n_param_values,
                                                                const GValue *param_values,
                                                                gpointer      invocation_hint,
                                                                gpointer      marshal_data);

/* VOID:STRING,STRING,ENUM,INT,INT (nautilus-marshal.list:20) */
extern void nautilus_marshal_VOID__STRING_STRING_ENUM_INT_INT (GClosure     *closure,
                                                               GValue       *return_value,
                                                               guint         n_param_values,
                                                               const GValue *param_values,
                                                               gpointer      invocation_hint,
                                                               gpointer      marshal_data);

/* VOID:STRING,ENUM,INT,INT (nautilus-marshal.list:21) */
extern void nautilus_marshal_VOID__STRING_ENUM_INT_INT (GClosure     *closure,
                                                        GValue       *return_value,
                                                        guint         n_param_values,
                                                        const GValue *param_values,
                                                        gpointer      invocation_hint,
                                                        gpointer      marshal_data);

/* VOID:STRING,STRING (nautilus-marshal.list:22) */
extern void nautilus_marshal_VOID__STRING_STRING (GClosure     *closure,
                                                  GValue       *return_value,
                                                  guint         n_param_values,
                                                  const GValue *param_values,
                                                  gpointer      invocation_hint,
                                                  gpointer      marshal_data);

/* VOID:POINTER,INT,STRING,STRING,ENUM,INT,INT (nautilus-marshal.list:23) */
extern void nautilus_marshal_VOID__POINTER_INT_STRING_STRING_ENUM_INT_INT (GClosure     *closure,
                                                                           GValue       *return_value,
                                                                           guint         n_param_values,
                                                                           const GValue *param_values,
                                                                           gpointer      invocation_hint,
                                                                           gpointer      marshal_data);

G_END_DECLS

#endif /* __nautilus_marshal_MARSHAL_H__ */

