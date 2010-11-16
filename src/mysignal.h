/* signal.h
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

#ifndef H_NIJ_SIGNAL_200908211038
#define H_NIJ_SIGNAL_200908211038

#include <glib-object.h>

G_BEGIN_DECLS

guint action_new (GType type, const char* signal_name);

G_END_DECLS

#endif /* H_NIJ_SIGNAL_200908211038 */

