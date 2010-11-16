/* signal.c
 *
 * Copyright (C) 2008-2010 Nicolas Joseph
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Author:
 * 	Nicolas Joseph <nicolas.joseph@valaide.org>
 */

#include "mysignal.h"

guint action_new (GType type, const char* signal_name)
{
  g_signal_new (signal_name, type, G_SIGNAL_RUN_LAST | G_SIGNAL_ACTION, 0, NULL,
                NULL, g_cclosure_marshal_VOID__VOID, G_TYPE_NONE, 0);
}

