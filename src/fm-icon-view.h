/*
 * Copyright (C) 2010 ammonkey
 *
 * This library is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License
 * version 3.0 as published by the Free Software Foundation.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License version 3.0 for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library. If not, see
 * <http://www.gnu.org/licenses/>.
 *
 * Author: ammonkey <am.monkeyd@gmail.com>
 */

#ifndef __FM_ICON_VIEW_H__
#define __FM_ICON_VIEW_H__

#include <fm-abstract-icon-view.h>

G_BEGIN_DECLS;

typedef struct FMIconViewClass FMIconViewClass;
typedef struct FMIconView      FMIconView;

#define FM_TYPE_ICON_VIEW             (fm_icon_view_get_type ())
#define FM_ICON_VIEW(obj)             (G_TYPE_CHECK_INSTANCE_CAST ((obj), FM_TYPE_ICON_VIEW, FMIconView))
#define FM_ICON_VIEW_CLASS(klass)     (G_TYPE_CHECK_CLASS_CAST ((klass), FM_TYPE_ICON_VIEW, FMIconViewClass))
#define FM_IS_ICON_VIEW(obj)          (G_TYPE_CHECK_INSTANCE_TYPE ((obj), FM_TYPE_ICON_VIEW))
#define FM_IS_ICON_VIEW_CLASS(klass)  (G_TYPE_CHECK_CLASS_TYPE ((obj), FM_TYPE_ICON_VIEW))
#define FM_ICON_VIEW_GET_CLASS(obj)   (G_TYPE_INSTANCE_GET_CLASS ((obj), FM_TYPE_ICON_VIEW, FMIconViewClass))

struct FMIconView
{
    FMAbstractIconView parent;
};

struct FMIconViewClass
{
    FMAbstractIconViewClass parent_class;
};

GType fm_icon_view_get_type (void) G_GNUC_CONST;

G_END_DECLS;

#endif /* !__FM_ICON_VIEW_H__ */
