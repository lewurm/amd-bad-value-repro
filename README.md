Repro for bad value issue on AMD Threadripper 1920X
===================================================

clone and run:
```
$ git clone https://github.com/lewurm/amd-bad-value-repro.git
$ cd amd-bad-value-repro/
$ cat repro.sh
$ ./repro.sh
```

it should crash with a message like this:
```
* Assertion at mini.c:2443, condition `cfg->num_bblocks >= dfn' not met, function:mono_bb_ordering, at iteration=7485 via "System.Uri:PrivateParseMinimal ()": cfg->num_bblocks=115/0x73,  dfn=21944/0x55b8, *(guint64 *) &dfn=0x5a


Stacktrace:

/proc/self/maps:
40139000-40149000 rwxp 00000000 00:00 0 
4158c000-4159c000 rwxp 00000000 00:00 0 
55b8ce2ad000-55b8ce6e5000 r-xp 00000000 08:12 1476674                    /home/bernhard/mono/repro/mono-sgen
55b8ce8e5000-55b8ce8ed000 r--p 00438000 08:12 1476674                    /home/bernhard/mono/repro/mono-sgen
55b8ce8ed000-55b8ce8f1000 rw-p 00440000 08:12 1476674                    /home/bernhard/mono/repro/mono-sgen
55b8ce8f1000-55b8ce907000 rw-p 00000000 00:00 0 
55b8cf944000-55b8cfa2c000 rw-p 00000000 00:00 0                          [heap]
7f48a0000000-7f48a0021000 rw-p 00000000 00:00 0 
7f48a0021000-7f48a4000000 ---p 00000000 00:00 0 
7f48a6f38000-7f48a7200000 r--p 00000000 08:12 1476673                    /home/bernhard/mono/repro/System.dll
7f48a7200000-7f48a7201000 ---p 00000000 00:00 0 
7f48a7201000-7f48a7202000 rw-p 00000000 00:00 0 
7f48a7202000-7f48a720a000 ---p 00000000 00:00 0 
7f48a720a000-7f48a7401000 rw-p 00000000 00:00 0 
7f48a7401000-7f48a77ff000 r--p 00000000 08:12 1471483                    /home/bernhard/mono/repro/mscorlib.dll
7f48a77ff000-7f48a87ff000 rw-p 00000000 00:00 0 
7f48a87ff000-7f48a8800000 ---p 00000000 00:00 0 
7f48a8800000-7f48a9400000 rw-p 00000000 00:00 0 
7f48a9492000-7f48a9f91000 r--p 00000000 08:12 1841981                    /usr/lib/locale/locale-archive
7f48a9f91000-7f48aa178000 r-xp 00000000 08:12 922789                     /lib/x86_64-linux-gnu/libc-2.27.so
7f48aa178000-7f48aa378000 ---p 001e7000 08:12 922789                     /lib/x86_64-linux-gnu/libc-2.27.so
7f48aa378000-7f48aa37c000 r--p 001e7000 08:12 922789                     /lib/x86_64-linux-gnu/libc-2.27.so
7f48aa37c000-7f48aa37e000 rw-p 001eb000 08:12 922789                     /lib/x86_64-linux-gnu/libc-2.27.so
7f48aa37e000-7f48aa382000 rw-p 00000000 00:00 0 
7f48aa382000-7f48aa399000 r-xp 00000000 08:12 922826                     /lib/x86_64-linux-gnu/libgcc_s.so.1
Memory around native instruction pointer (0x7f48a9fcfe97):
0x7f48a9fcfe87  d2 4c 89 ce bf 02 00 00 00 b8 0e 00 00 00 0f 05  .L..............
0x7f48a9fcfe97  48 8b 8c 24 08 01 00 00 64 48 33 0c 25 28 00 00  H..$....dH3.%(..
0x7f48a9fcfea7  00 44 89 c0 75 1f 48 81 c4 18 01 00 00 c3 0f 1f  .D..u.H.........
0x7f48a9fcfeb7  00 48 8b 15 a9 bf 3a 00 f7 d8 41 b8 ff ff ff ff  .H....:...A.....
./repro.sh: line 3: 110556 Aborted                 (core dumped) MONO_PATH="`pwd`" ./mono-sgen --compile 'System.Uri:PrivateParseMinimal' mscorlib -O=-aot --debug
```


The crash happens here: https://github.com/lewurm/mono/blob/ee8ed94d634f2e91580ab234605ee19d11263193/mono/mini/mini.c#L2439-L2444

Note, with the following patch the crash is _not_ reproducible:

```patch
diff --git a/mono/mini/mini.c b/mono/mini/mini.c
index 456568d4521..d95cc2b0d36 100644
--- a/mono/mini/mini.c
+++ b/mono/mini/mini.c
@@ -2440,9 +2440,9 @@ mono_bb_ordering (MonoCompile *cfg)
                clear_bb_stuff (cfg);
                dfn = 0;
                df_visit (cfg->bb_entry, &dfn, cfg->bblocks);
+               mono_memory_barrier ();
                g_assertf (cfg->num_bblocks >= dfn, "at iteration=%d via \"%s\": cfg->num_bblocks=%d/0x%x,  dfn=%d/0x%x, *(guint64 *) &dfn=%p\n", i, mono_method_full_name (cfg->method, 1), cfg->num_bblocks, cfg->num_bblocks, dfn, dfn, *(guint64 *) &dfn);
        }
-       mono_memory_barrier ();
        if (cfg->num_bblocks != dfn + 1) {
                call_something_else (cfg, dfn);
        }
```

the included binary `mono-sgen_NOCRASH` is compiled with that patch. The disasm for `mini_method_compile ()` (this method inlines `mono_bb_ordering`) is included in 
* `mono-sgen.disasm.mini_method_compile` for the crashing version
* `mono-sgen_NOCRASH.disasm.mini_method_compile` for the non crashing version

asm diff:
![assembler diff](/asmdiff.png?raw=true "Optional Title")


System info
===========

```
$ uname -a
Linux beowulf 4.17.7-041707-generic #201807171133 SMP Tue Jul 17 20:02:58 CEST 2018 x86_64 x86_64 x86_64 GNU/Linux

$ cat /etc/issue
Ubuntu 18.04 LTS \n \l

$ ldd mono-sgen
	linux-vdso.so.1 (0x00007ffdf415a000)
	libm.so.6 => /lib/x86_64-linux-gnu/libm.so.6 (0x00007f2e48a47000)
	librt.so.1 => /lib/x86_64-linux-gnu/librt.so.1 (0x00007f2e4883f000)
	libdl.so.2 => /lib/x86_64-linux-gnu/libdl.so.2 (0x00007f2e4863b000)
	libpthread.so.0 => /lib/x86_64-linux-gnu/libpthread.so.0 (0x00007f2e4841c000)
	libgcc_s.so.1 => /lib/x86_64-linux-gnu/libgcc_s.so.1 (0x00007f2e48204000)
	libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007f2e47e13000)
	/lib64/ld-linux-x86-64.so.2 (0x00007f2e4943f000)

$ gcc --version
gcc (Ubuntu 7.3.0-16ubuntu3) 7.3.0
Copyright (C) 2017 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
```

Related
=======
https://github.com/mono/mono/issues/9298#issuecomment-400467839
