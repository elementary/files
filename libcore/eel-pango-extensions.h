/*-
 * Copyright (c) 2006 Benedikt Meurer <benny@xfce.org>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2 of the License, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street,
 * Fifth Floor Boston, MA 02110-1335 USA.
 */

#ifndef __EEL_PANGO_EXTENSIONS_H__
#define __EEL_PANGO_EXTENSIONS_H__

#include <pango/pango.h>

G_BEGIN_DECLS;

PangoAttrList *eel_pango_attr_list_big               (void) G_GNUC_CONST;
PangoAttrList *eel_pango_attr_list_small             (void) G_GNUC_CONST;
PangoAttrList *eel_pango_attr_list_big_bold          (void) G_GNUC_CONST;
PangoAttrList *eel_pango_attr_list_bold              (void) G_GNUC_CONST;
PangoAttrList *eel_pango_attr_list_italic            (void) G_GNUC_CONST;
PangoAttrList *eel_pango_attr_list_small_italic      (void) G_GNUC_CONST;
PangoAttrList *eel_pango_attr_list_underline_single  (void) G_GNUC_CONST;
PangoAttrList *eel_pango_attr_list_small_underline_single (void) G_GNUC_CONST;

G_END_DECLS;

#endif /* !__EEL_PANGO_EXTENSIONS_H__ */
