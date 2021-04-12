#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>
#include <stdbool.h>

#include <arcan_shmif.h>

static void clear_cont(struct arcan_shmif_cont* c, uint8_t r, uint8_t g, uint8_t b)
{
	for (size_t row = 0; row < c->h; row++)
		for (size_t col = 0; col < c->w; col++){
		c->vidp[ row * c->pitch + col ] = SHMIF_RGBA(r, g, b, 0xff);
	}
	arcan_shmif_signal(c, SHMIF_SIGVID);
}

int main(int argc, char** argv)
{
	struct arcan_shmif_cont cont =
		arcan_shmif_open(SEGID_MEDIA, SHMIF_ACQUIRE_FATALFAIL, NULL);

	struct arcan_shmif_initial* init;
	size_t init_sz = arcan_shmif_initial(&cont, &init);

/* assert(init_sz == sizeof(*init)) as cheap versioning -
 * init contains useful information for producing 'correct' content,
 * e.g. color-scheme, default font, desired font size, locale, ... */

	clear_cont(&cont, 127, 0, 0);

/* to indicate that we are working, progress state can be sent with:
 	arcan_shmif_enqueue(c, &(struct arcan_event){
		.ext.kind = ARCAN_EVENT(STREAMSTATUS),
		.ext.streamstat = {
			.completion = 0.5f (0 .. 1.0)
		}
	});

	see arcan_shmif_event.h for the full list of EXTERNAL
	(client->server), TARGET (server->client) and IO events
*/

	struct arcan_event ev;
	while(arcan_shmif_wait(&cont, &ev)){
		if (ev.category != EVENT_TARGET)
			continue;

		switch (ev.tgt.kind){

		case TARGET_COMMAND_RESET:
			clear_cont(&cont, rand() % 255, rand() % 255, rand() % 255);
/* ev->ioevs[0].iv:
 *      0, 1 == soft (re-run),
 *      2,3 == hard (as if first time in main)
 */
		break;

		case TARGET_COMMAND_BCHUNK_IN:
/* triggered when we have an INCOMING data-stream from some source */
		break;

		case TARGET_COMMAND_BCHUNK_OUT:
/* triggered when we should write OUTGOING data into
 * ioevs[0].iv (dup the descriptor with arcan_shmif_dupfd, and possibly
 *              use the arcan_shmif_bgcopy to get a thread going, see
 *              arcan_shmif_interop.h) */
		break;

/*
 * Other interesting events:
 *  FONTHINT - server sent a new font for text rendering
 *  DISPLAYHINT/OUTPUTHINT - resize or assigned to a display with new properties
 *  SEEKCONTENT - if we have previously sent a content hint to indicate that we
 *                can be scrolled / seeked, this is the user response to that
 *  NEWSEGMENT - if an alternate data stream is pushed or requested through SEGREQ
 */
		case TARGET_COMMAND_EXIT:
			goto out;
		break;
		default:
		break;
		}
	}

out:
	return EXIT_SUCCESS;
}
