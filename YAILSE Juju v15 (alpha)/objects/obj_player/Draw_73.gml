///Draw End

if ( lighting_deferred ) {
	lighting_draw_end_deferred();
} else {
	lighting_draw_end();
}