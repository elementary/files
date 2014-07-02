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

//#ifndef GOF_WINDOW_SLOT_DEFINED
//#define GOF_WINDOW_SLOT_DEFINED

//typedef struct _GOFWindowSlot GOFWindowSlot;
//typedef struct _GOFWindowSlotClass GOFWindowSlotClass;
//typedef struct _GOFWindowSlotPrivate GOFWindowSlotPrivate;

//struct _GOFWindowSlot {
	//GOFAbstractSlot parent_instance;
	//GOFWindowSlotPrivate * priv;
	//GOFDirectoryAsync* directory;
	//GFile* location;
	//GtkBox* content_box;
	//FMDirectoryView* view_box;
	//GtkBox* colpane;
	//GraniteWidgetsThinPaned* hpane;
	//MarlinViewViewContainer* ctab;
	//MarlinWindowColumns* mwcols;
//};

//struct _GOFWindowSlotClass {
	//GOFAbstractSlotClass parent_class;
//};
//#endif /* GOF_WINDOW_SLOT_DEFINED */

typedef enum {
	MARLIN_WINDOW_OPEN_FLAG_DEFAULT,
	MARLIN_WINDOW_OPEN_FLAG_NEW_TAB,
	MARLIN_WINDOW_OPEN_FLAG_NEW_WINDOW
} MarlinViewWindowOpenFlags;

#endif /* MARLIN_VIEW_WINDOW_H */
