/*
 * UbuntuOne Nautilus plugin
 *
 * Authors: Rodrigo Moya <rodrigo.moya@canonical.com>
 *
 * Copyright 2009-2010 Canonical Ltd.
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 3, as published
 * by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#ifndef __CONTEXT_MENU_H__
#define __CONTEXT_MENU_H__

//#include <libnautilus-extension/nautilus-menu-provider.h>
//#include "ubuntuone-nautilus.h"
#include "plugin.h"

/*NautilusMenuItem *context_menu_new (MarlinPluginsUbuntuOne *uon,
                                    GtkWidget *window,
                                    GList *files);*/

void context_menu_new (MarlinPluginsUbuntuOne *u1, GtkWidget *menu);

#endif
