/*
 * marlin-plugin-hook.h
 * Copyright (C) Lucas Baudin 2011 <xapantu@gmail.com>
 * 
 * marlin-plugin-hook.h is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * marlin-plugin-hook.h is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef _H_MARLIN_PLUGINS_HOOK
#define _H_MARLIN_PLUGINS_HOOK
enum
{
    MARLIN_PLUGIN_HOOK_INTERFACE,
    MARLIN_PLUGIN_HOOK_CONTEXT_MENU,
    MARLIN_PLUGIN_HOOK_UI,
    MARLIN_PLUGIN_HOOK_FINISH,
    MARLIN_PLUGIN_HOOK_DIRECTORY, /* {window, viewcontainer, directory name } */
    MARLIN_PLUGIN_HOOK_FILE,
    MARLIN_PLUGIN_HOOK_INIT,
    MARLIN_PLUGIN_HOOK_SIDEBAR /* { sidebar } */
};
#endif
