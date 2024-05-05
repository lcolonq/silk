#include "angband.h"

#ifdef USE_EMACS

#include "main.h"

static term t;

static void print_player_info() {
	if (!z_info || !b_info || !p_name || !c_name || !hp_ptr || !rp_ptr) return;
	printf("(player-info");
	printf(" :hp (%d %d)", p_ptr->chp, p_ptr->mhp);
	printf(" :voice (%d %d)", p_ptr->csp, p_ptr->msp);
	printf(" :exp (%d %d)", p_ptr->new_exp, p_ptr->exp);
	printf(" :burden (%d %d)", p_ptr->total_weight, weight_limit());
	printf(" :str (%d %d %d)", p_ptr->stat_use[A_STR], p_ptr->stat_drain[A_STR], p_ptr->tmp_str);
	printf(" :dex (%d %d %d)", p_ptr->stat_use[A_DEX], p_ptr->stat_drain[A_DEX], p_ptr->tmp_dex);
	printf(" :con (%d %d %d)", p_ptr->stat_use[A_CON], p_ptr->stat_drain[A_CON], p_ptr->tmp_con);
	printf(" :gra (%d %d %d)", p_ptr->stat_use[A_GRA], p_ptr->stat_drain[A_GRA], p_ptr->tmp_gra);
	printf(" :melee (%d %d %d)", p_ptr->skill_use[S_MEL], p_ptr->mdd, p_ptr->mds);
	printf(" :archery (%d %d %d)", p_ptr->skill_use[S_ARC], p_ptr->add, p_ptr->ads);
	printf(" :evasion %d", p_ptr->skill_use[S_EVN]);

	if (p_ptr->song2 != SNG_NOTHING) {
		char *song1_name = b_name + (&b_info[ability_index(S_SNG, p_ptr->song1)])->name;
		char *song2_name = b_name + (&b_info[ability_index(S_SNG, p_ptr->song2)])->name;
		printf(" :song (\"%s\" \"%s\")", song1_name, song2_name);
	} else if (p_ptr->song1 != SNG_NOTHING) {
		char *song1_name = b_name + (&b_info[ability_index(S_SNG, p_ptr->song1)])->name;
		printf(" :song (\"%s\")", song1_name);
	} else {
		printf(" :song nil");
	}

	printf(" :poison %d", p_ptr->poisoned);
	printf(" :stealth %s", p_ptr->stealth_mode ? "t" : "nil");

	printf(" :name \"%s\"", op_ptr->full_name);
	printf(" :race \"%s\"", p_name + rp_ptr->name);
	printf(" :house \"%s\"", c_name + hp_ptr->short_name);
	printf(" :depth %d", p_ptr->depth);
	printf(" :age %d", p_ptr->age);
	printf(" :height %d", p_ptr->ht);
	printf(" :weight %d", p_ptr->wt);
	printf(" :gameturn %d", playerturn);
	printf(")\n");
}

static void print_map() {
	byte a, ta;
	char c, tc;
	printf("(map %d %d (", SCREEN_WID, SCREEN_HGT);
	for (int oy = 0; oy < SCREEN_HGT; ++oy) {
		for (int ox = 0; ox < SCREEN_WID; ++ox) {
			int x = ox + p_ptr->wx;
			int y = oy + p_ptr->wy;
            if (!in_bounds(y, x)) continue;
            map_info(y, x, &a, &c, &ta, &tc);
			if (c) {
				printf("(\"%c\" %d) ", c, a);
			} else {
				printf("(\" \" 1) ");
			}
		}
	}
	printf("))\n");
}

static void print_inventory() {
	char desc[80];
	printf("(inventory (");
	if (inventory) {
		for (int i = 0; i < INVEN_PACK; ++i) {
			if (!inventory[i].k_idx) continue;
			object_type *o = &inventory[i];
			object_desc(desc, sizeof(desc), o, TRUE, 3);
			printf("\"%s\" ", desc);
		}
	}
	printf("))\n");
}

static errr event_handler_xtra(int n, int v) {
	switch (n) {
	case TERM_XTRA_EVENT: {
		/*
		 * Process some pending events XXX XXX XXX
		 *
		 * Wait for at least one event if "v" is non-zero
		 * otherwise, if no events are ready, return at once.
		 * When "keypress" events are encountered, the "ascii"
		 * value corresponding to the key should be sent to the
		 * "Term_keypress()" function.  Certain "bizarre" keys,
         * such as function keys or arrow keys, may send special
         * sequences of characters, such as control-underscore,
         * plus letters corresponding to modifier keys, plus an
         * underscore, plus carriage return, which can be used by
         * the main program for "macro" triggers.  This action
         * should handle as many events as is efficiently possible
         * but is only required to handle a single event, and then
         * only if one is ready or "v" is true.
         *
         * This action is required.
         */

		int i = getchar();
        if (i < 0) return 1;
		if (i == '\n') return 0;
		Term_keypress(i);
        return 0;
    }

    case TERM_XTRA_FLUSH: {
        /*
         * Flush all pending events XXX XXX XXX
         *
         * This action should handle all events waiting on the
         * queue, optionally discarding all "keypress" events,
         * since they will be discarded anyway in "z-term.c".
         *
         * This action is required, but may not be "essential".
         */

        return 0;
    }

    case TERM_XTRA_FRESH: {
        /*
         * Flush output XXX XXX XXX
         *
         * This action should make sure that all "output" to the
         * window will actually appear on the window.
         *
         * This action is optional, assuming that "Term_text_xxx()"
         * (and similar functions) draw directly to the screen, or
         * that the "TERM_XTRA_FROSH" entry above takes care of any
         * necessary flushing issues.
         */

		print_player_info();
		print_map();
		print_inventory();
        return 0;
    }

    case TERM_XTRA_REACT: {
        /*
         * React to global changes XXX XXX XXX
         *
         * For example, this action can be used to react to
         * changes in the global "angband_color_table[256][4]" array.
         *
         * This action is optional, but can be very useful for
         * handling "color changes" and the "arg_sound" and/or
         * "arg_graphics" options.
         */

        return 0;
    }

    case TERM_XTRA_CLEAR:
    case TERM_XTRA_SHAPE:
    case TERM_XTRA_FROSH:
    case TERM_XTRA_NOISE:
    case TERM_XTRA_SOUND:
    case TERM_XTRA_BORED:
    case TERM_XTRA_ALIVE:
    case TERM_XTRA_LEVEL:
    case TERM_XTRA_DELAY:
        return 0;
	}

    return 1;
}

int main(int argc, char *argv[]) {
    ANGBAND_SYS = "emacs";

    term_init(&t, 80, 24, 256);
    t.xtra_hook = event_handler_xtra;
    Term_activate(&t);
	term_screen = &t;

    char path[1024];
    strcpy(path, "lib/");
    init_file_paths(path);

    init_angband();

	char buf[80];
	path_build(savefile, sizeof(buf), ANGBAND_DIR_XTRA, "tutorial");
	play_game(FALSE);
}

#endif /* USE_XXX */
