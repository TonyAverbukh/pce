/*****************************************************************************
 * pce                                                                       *
 *****************************************************************************/

/*****************************************************************************
 * File name:   src/devices/video.h                                          *
 * Created:     2003-08-30 by Hampa Hug <hampa@hampa.ch>                     *
 * Copyright:   (C) 2003-2008 Hampa Hug <hampa@hampa.ch>                     *
 *****************************************************************************/

/*****************************************************************************
 * This program is free software. You can redistribute it and / or modify it *
 * under the terms of the GNU General Public License version 2 as  published *
 * by the Free Software Foundation.                                          *
 *                                                                           *
 * This program is distributed in the hope  that  it  will  be  useful,  but *
 * WITHOUT  ANY   WARRANTY,   without   even   the   implied   warranty   of *
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU  General *
 * Public License for more details.                                          *
 *****************************************************************************/

/* $Id$ */


#ifndef PCE_VIDEO_H
#define PCE_VIDEO_H 1


#include <stdio.h>

#include <devices/memory.h>


typedef struct {
	void      (*del) (void *ext);

	int       (*set_msg) (void *ext, const char *msg, const char *val);

	void      (*set_terminal) (void *ext, void *trm);

	mem_blk_t *(*get_mem) (void *ext);
	mem_blk_t *(*get_reg) (void *ext);

	void      (*print_info) (void *ext, FILE *fp);

	int       (*screenshot) (void *ext, FILE *fp, unsigned mode);

	void      (*redraw) (void *ext);
	void      (*clock) (void *ext, unsigned long cnt);

	void      *ext;

	/* the dot clock (clock, remainder, last) */
	unsigned long dotclk[3];
} video_t;


/*!***************************************************************************
 * @short Increase the clock count without calling the clock() function
 *****************************************************************************/
#define pce_video_clock0(vid, cnt, div) do { \
	(vid)->dotclk[0] += ((cnt) + (vid)->dotclk[1]) / (div); \
	(vid)->dotclk[1] = ((cnt) + (vid)->dotclk[1]) % (div); \
	} while (0)


void pce_video_init (video_t *vid);
void pce_video_del (video_t *vid);

/*!***************************************************************************
 * @short Send a message to a video device
 *****************************************************************************/
int pce_video_set_msg (video_t *vid, const char *msg, const char *val);

void pce_video_set_terminal (video_t *vid, void *trm);

mem_blk_t *pce_video_get_mem (video_t *vid);
mem_blk_t *pce_video_get_reg (video_t *vid);

void pce_video_print_info (video_t *vid, FILE *fp);

int pce_video_screenshot (video_t *vid, FILE *fp, unsigned mode);

void pce_video_redraw (video_t *vid);

void pce_video_clock1 (video_t *vid, unsigned long cnt);


#endif
