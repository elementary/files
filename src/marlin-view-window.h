/* -*- Mode: C; indent-tabs-mode: t; c-basic-offset: 8; tab-width: 8 -*- */
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

#ifndef MARLIN_VIEW_WINDOW_H
#define MARLIN_VIEW_WINDOW_H

#define MARLIN_TYPE_OPEN_FLAG (marlin_open_flag_get_type ())

typedef enum
{
    MARLIN_OPEN_FLAG_DEFAULT,
    MARLIN_OPEN_FLAG_NEW_ROOT,
    MARLIN_OPEN_FLAG_NEW_TAB,
    MARLIN_OPEN_FLAG_NEW_WINDOW
} MarlinOpenFlag;

GType           marlin_open_flag_get_type     (void) G_GNUC_CONST;

#define MARLIN_TYPE_VIEW_MODE (marlin_view_mode_get_type ())

typedef enum
{
    MARLIN_VIEW_MODE_ICON,
    MARLIN_VIEW_MODE_LIST,
    MARLIN_VIEW_MODE_MILLER_COLUMNS,
    MARLIN_VIEW_MODE_CURRENT,
    MARLIN_VIEW_MODE_PREFERRED,
    MARLIN_VIEW_MODE_INVALID,
} MarlinViewMode;

GType           marlin_view_mode_get_type     (void) G_GNUC_CONST;
#endif /* MARLIN_VIEW_WINDOW_H */
