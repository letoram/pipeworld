/* this is just cherry-picked from arcan_shmif_debugif.c
 * -- missing handlers for reset (seek to beginning)
 * -- missing handler for bchunk setting stdin / stdout
 */

#include <arcan_shmif.h>
#include <arcan_tui.h>

#include <arcan_tuisym.h>
#include <arcan_tui_listwnd.h>
#include <arcan_tui_bufferwnd.h>

#include <inttypes.h>
#include <stdarg.h>
#include <errno.h>
#include <poll.h>
#include <fcntl.h>

struct mim_buffer_opts {
	size_t size;
	size_t step_sz;
};

/* flush buf to stdout,
 * update progress and window 'status' until completed (or terminated) --
 * should have a custom colorizer as well that shows the bytes that have
 * been flushed and those that haven't */
static bool mim_flush(
	struct tui_context* tui,
	struct mim_buffer_opts mim_opts,
	uint8_t* buf, size_t buf_sz, int fdout)
{
	size_t buf_pos = 0;
/* it's not that we really can do anything in the context of errors here */
	int rfl = fcntl(fdout, F_GETFL);
	fcntl(fdout, F_SETFL, rfl | O_NONBLOCK);

	struct tui_bufferwnd_opts opts = {
		.read_only = true,
		.view_mode = BUFFERWND_VIEW_HEX_DETAIL,
		.allow_exit = false
	};

/* setup a new buffer window with our output buffer, color / seek as are written */
	arcan_tui_bufferwnd_setup(tui,
		buf, buf_sz, &opts, sizeof(struct tui_bufferwnd_opts));

	struct pollfd pfd[2] = {
		{
			.fd = fdout,
			.events = POLLOUT | POLLERR | POLLNVAL | POLLHUP
		},
		{
			.events = POLLIN | POLLERR | POLLNVAL | POLLHUP
		}
	};

/* keep going until the buffer is sent or something happens */
	int status;
	while(buf_sz && buf_pos < buf_sz &&
		1 == (status = arcan_tui_bufferwnd_status(tui))){
		arcan_tui_get_handles(&tui, 1, &pfd[1].fd, 1);
		poll(pfd, 2, -1);
		if (pfd[0].revents){
/* error */
			if (!(pfd[0].revents & POLLOUT)){
				arcan_tui_bufferwnd_release(tui);
				arcan_tui_destroy(tui, "output pipe broken");
				return false;
			}

/* write and update output window */
			ssize_t nw = write(fdout, &buf[buf_pos], buf_sz - buf_pos);
			if (nw > 0){
				buf_pos += nw;
				arcan_tui_bufferwnd_seek(tui, buf_pos);
				arcan_tui_progress(tui,
					TUI_PROGRESS_INTERNAL, (float)buf_pos / (float)buf_sz);
			}
		}

/* and always update the window */
		arcan_tui_process(&tui, 1, NULL, 0, 0);
		arcan_tui_refresh(tui);
	}

	arcan_tui_bufferwnd_release(tui);
	return true;
}

static void mim_window(
	struct tui_context* tui, int fdin, int fdout, struct mim_buffer_opts bopts)
{
	struct tui_bufferwnd_opts opts = {
		.read_only = false,
		.view_mode = BUFFERWND_VIEW_HEX_DETAIL,
		.allow_exit = true
	};

/* switch window, wait for buffer */
	size_t buf_sz = bopts.size;
	size_t buf_pos = 0;
	uint8_t* buf = malloc(buf_sz);
	if (!buf)
		return;

/* would be convenient with a message area that gets added, there's also the
 * titlebar and buffer control - ideally this would even be a re-usable helper
 * with bufferwnd rather than here */
refill:
	arcan_tui_bufferwnd_setup(tui,
		buf, 0, &opts, sizeof(struct tui_bufferwnd_opts));

	memset(buf, '\0', buf_sz);

	bool read_data = true;
	int status;

/*
 * processing loop, end conditions:
 *  - error: destroy and leave
 *  - buffer presented, user asks to commit
 *  - buffer presented, user destroyed window
 */
	while(1 == (status = arcan_tui_bufferwnd_status(tui))){
		struct tui_process_res res;
		if (read_data){
			res = arcan_tui_process(&tui, 1, &fdin, 1, -1);
		}
		else
			res = arcan_tui_process(&tui, 1, NULL, 0, -1);

/* fill buffer if needed */
		if (res.ok){
			if (buf_sz - buf_pos > 0){
				ssize_t nr = read(fdin, &buf[buf_pos], buf_sz - buf_pos);

/* eof */
				if (nr == 0){
					if (buf_pos == 0){
						arcan_tui_bufferwnd_release(tui);
						arcan_tui_destroy(tui, NULL);
						free(buf);
						return;
					}
					read_data = false;
				}

/* bad pipe */
				if (nr == -1 && errno != EINTR && errno != EWOULDBLOCK && errno != EAGAIN){
					arcan_tui_bufferwnd_release(tui);
					arcan_tui_destroy(tui, "input broken");
					free(buf);
					return;
				}

/* more to be read */
				if (nr > 0){
					buf_pos += nr;

/* more data has arrived, but keep current cursor position */
					arcan_tui_bufferwnd_synch(tui,
						buf, buf_pos, arcan_tui_bufferwnd_tell(tui, NULL));

					if (buf_sz == buf_pos)
						read_data = false;
				}
			}
		}

		if (-1 == arcan_tui_refresh(tui) && errno == EINVAL)
			break;
	}

/* remember user buffer window options so we can restore,
 * then switch to read-only view of the buffer and start flushing to fdout,
 * if flushing fails it will set last words and destroy the tui context */
	arcan_tui_bufferwnd_tell(tui, &opts);
	arcan_tui_bufferwnd_release(tui);

	if (status != 0 ||
		!mim_flush(tui, bopts, buf, buf_pos, fdout)){
		free(buf);
		return;
	}

	buf_pos = 0;
	goto refill;

	arcan_tui_update_handlers(tui,
		&(struct tui_cbcfg){}, NULL, sizeof(struct tui_cbcfg));
	free(buf);
}

int main(int argc, char** argv)
{
	struct tui_cbcfg cbcfg = {};
	arcan_tui_conn* conn = arcan_tui_open_display("test", "");
	struct tui_context* tui = arcan_tui_setup(conn, NULL, &cbcfg, sizeof(cbcfg));

	int fdin = STDIN_FILENO;
	int fdout = STDOUT_FILENO;

/* open through arguments as well in order to make it less of a pain to gdb */
/* (missing) other options:
 * 1. control block size
 * 2. expose step control
 * 3. stdin / stdout or bchunk- mode
 * 4. progress writing / commit
 */
	int ind = 1;
	while(ind < argc){
		if (strcmp(argv[ind], "-input") == 0){
			ind++;
			if (ind == argc){
				fprintf(stderr, "-input without a filename\n");
				return EXIT_FAILURE;
			}
			fdin = open(argv[ind], O_RDONLY);
			if (-1 == fdin){
				fprintf(stderr, "-input %s : couldn't open, reason: %s\n", argv[ind], strerror(errno));
				return EXIT_FAILURE;
			}
		}
		else if (strcmp(argv[ind], "-output") == 0){
			ind++;
			if (ind == argc){
				fprintf(stderr, "-output without a filename\n");
				return EXIT_FAILURE;
			}
			fdout = open(argv[ind], O_CREAT | O_RDWR, S_IRWXU);
			if (-1 == fdout){
				fprintf(stderr, "-output %s : couldn't open, reason: %s\n", argv[ind], strerror(errno));
				return EXIT_FAILURE;
			}
		}
		else {
			fprintf(stderr, "unknown argument: %s (allowed: -input fn -output fn)\n", argv[ind]);
			return EXIT_FAILURE;
		}
		ind++;
	}

	size_t block_size = 512;

	mim_window(tui, fdin, fdout, (struct mim_buffer_opts){.size = block_size});

	return EXIT_SUCCESS;
}
