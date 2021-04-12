project('pipeedit', 'c', default_options : ['c_std=c11'])
shmif = dependency('arcan-shmif')
tui = dependency('arcan-shmif-tui')
thread = dependency('threads')
cc = meson.get_compiler('c')
math = cc.find_library('m', required : false)
executable('pipeedit',
	['src/pipeedit.c'],
	install : true, dependencies : [shmif, tui, math, thread])
