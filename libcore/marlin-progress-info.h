/*
 * nautilus-progress-info.h: file operation progress info.
 *
 * Copyright (C) 2007 Red Hat, Inc.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Author: Alexander Larsson <alexl@redhat.com>
 */

#ifndef MARLIN_PROGRESS_INFO_H
#define MARLIN_PROGRESS_INFO_H

#include <glib-object.h>
#include <gio/gio.h>

/* Match .vapi class Marlin.Progress.Info */
#define MARLIN_PROGRESS_TYPE_INFO         (marlin_progress_info_get_type ())
#define MARLIN_PROGRESS_INFO(o)           (G_TYPE_CHECK_INSTANCE_CAST ((o), MARLIN_PROGRESS_TYPE_INFO, MarlinProgressInfo))
#define MARLIN_PROGRESS_INFO_CLASS(k)     (G_TYPE_CHECK_CLASS_CAST((k), MARLIN_PROGRESS_TYPE_INFO, MarlinProgressInfoClass))
#define MARLIN_PROGRESS_IS_INFO(o)        (G_TYPE_CHECK_INSTANCE_TYPE ((o), MARLIN_PROGRESS_TYPE_INFO))
#define MARLIN_PROGRESS_IS_INFO_CLASS(k)  (G_TYPE_CHECK_CLASS_TYPE ((k), MARLIN_PROGRESS_TYPE_INFO))
#define MARLIN_PROGRESS_INFO_GET_CLASS(o) (G_TYPE_INSTANCE_GET_CLASS ((o), MARLIN_PROGRESS_TYPE_INFO, MarlinProgressInfoClass))

typedef struct _MarlinProgressInfo      MarlinProgressInfo;
typedef struct _MarlinProgressInfoClass MarlinProgressInfoClass;

GType marlin_progress_info_get_type (void) G_GNUC_CONST;

/* Signals:
   "changed" - status or details changed
   "progress-changed" - the percentage progress changed (or we pulsed if in activity_mode
   "started" - emited on job start
   "finished" - emitted when job is done

   All signals are emitted from idles in main loop.
   All methods are threadsafe.
   */

MarlinProgressInfo *marlin_progress_info_new (void);

GList *       nautilus_get_all_progress_info (void);

char *        marlin_progress_info_get_title       (MarlinProgressInfo *info);
char *        marlin_progress_info_get_status      (MarlinProgressInfo *info);
char *        marlin_progress_info_get_details     (MarlinProgressInfo *info);
double        marlin_progress_info_get_progress    (MarlinProgressInfo *info);
GCancellable *marlin_progress_info_get_cancellable (MarlinProgressInfo *info);
void          marlin_progress_info_cancel          (MarlinProgressInfo *info);
gboolean      marlin_progress_info_get_is_started  (MarlinProgressInfo *info);
gboolean      marlin_progress_info_get_is_finished (MarlinProgressInfo *info);
gboolean      marlin_progress_info_get_is_paused   (MarlinProgressInfo *info);
double        marlin_progress_info_get_current     (MarlinProgressInfo *info);
double        marlin_progress_info_get_total       (MarlinProgressInfo *info);

void          marlin_progress_info_start           (MarlinProgressInfo *info);
void          marlin_progress_info_finish          (MarlinProgressInfo *info);
void          marlin_progress_info_pause           (MarlinProgressInfo *info);
void          marlin_progress_info_resume          (MarlinProgressInfo *info);
void          marlin_progress_info_set_status      (MarlinProgressInfo *info,
                                                    const char         *status);
void          marlin_progress_info_take_status     (MarlinProgressInfo *info,
                                                    char               *status);
void          marlin_progress_info_set_details     (MarlinProgressInfo *info,
                                                    const char         *details);
void          marlin_progress_info_take_details    (MarlinProgressInfo *info,
                                                    char               *details);
void          marlin_progress_info_set_progress    (MarlinProgressInfo *info,
                                                    double             current,
                                                    double             total);
void          marlin_progress_info_pulse_progress  (MarlinProgressInfo *info);



#endif /* MARLIN_PROGRESS_INFO_H */
