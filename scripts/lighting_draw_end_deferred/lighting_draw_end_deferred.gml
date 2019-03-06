//  Build shadow casting geometry and render lights, with their shadows, to a screen-space lighting surface.
//  Should be called in one object per room, the same object that called scr_lighting_start().
//  This script changes the d3d_set_culling() internal value!
//  
//  argument0: Culling value to be set after the script has ended.
//  return: Nothing
//  
//  April 2017
//  @jujuadams
//  /u/jujuadam
//  Juju on the GMC
//
//  Based on the YAILSE system by xot (John Leffingwell) of gmlscripts.com
//  
//  This code and engine are provided under the Creative Commons "Attribution - NonCommerical - ShareAlike" international license.
//  https://creativecommons.org/licenses/by-nc-sa/4.0/

//var _old_culling      = gpu_get_cullmode();
//var _old_world_matrix = matrix_get( matrix_world );
//var _old_view_matrix  = matrix_get( matrix_view );
//var _old_proj_matrix  = matrix_get( matrix_projection );

var _camera_l = camera_get_view_x( lighting_camera );
var _camera_t = camera_get_view_y( lighting_camera );
var _camera_w = camera_get_view_width( lighting_camera );
var _camera_h = camera_get_view_height( lighting_camera );
var _camera_r = _camera_l + _camera_w;
var _camera_b = _camera_t + _camera_h;

var _camera_exp_l = _camera_l - LIGHTING_DYNAMIC_BORDER;
var _camera_exp_t = _camera_t - LIGHTING_DYNAMIC_BORDER;
var _camera_exp_r = _camera_r + LIGHTING_DYNAMIC_BORDER;
var _camera_exp_b = _camera_b + LIGHTING_DYNAMIC_BORDER;



///////////One-time construction of the static shadow-casting geometry
if ( vbf_static_shadows == noone ) {

    //Create a new vertex buffer
    vbf_static_shadows = vertex_create_buffer();
    
    //Add static shadow caster vertices to the relevant vertex buffer
    vertex_begin( vbf_static_shadows, vft_shadow_geometry );
    with ( obj_static_occluder ) __lighting_add_occlusion( other.vbf_static_shadows );
    vertex_end( vbf_static_shadows );
    
    //Freeze this buffer for speed boosts later on (though only if we have vertices in this buffer)
    if ( vertex_get_number( vbf_static_shadows ) > 0 ) vertex_freeze( vbf_static_shadows );
    
}



///////////Refresh the dynamic geometry
//Try to keep dynamic objects limited.
if ( LIGHTING_REUSE_DYNAMIC_BUFFER ) {
	if ( vbf_dynamic_shadows == noone ) vbf_dynamic_shadows = vertex_create_buffer();
} else {
	if ( vbf_dynamic_shadows != noone ) vertex_delete_buffer( vbf_dynamic_shadows );
	vbf_dynamic_shadows = vertex_create_buffer();
}

//Add dynamic shadow caster vertices to the relevant vertex buffer
vertex_begin( vbf_dynamic_shadows, vft_3d_textured );
with ( obj_dynamic_occluder ) {
    on_screen = visible and rectangle_in_rectangle_custom( bbox_left, bbox_top,
	                                                       bbox_right, bbox_bottom,
								                           _camera_exp_l, _camera_exp_t,
													       _camera_exp_r, _camera_exp_b );
	if ( on_screen ) __lighting_add_occlusion( other.vbf_dynamic_shadows );
}
vertex_end( vbf_dynamic_shadows );



///////////Render out lights and shadows for each light in the viewport
gpu_set_cullmode( lighting_culling );
with( obj_par_light ) {
	
    on_screen = visible and rectangle_in_rectangle_custom( x - light_w_half, y - light_h_half,
                                                           x + light_w_half, y + light_h_half,
								                           _camera_l, _camera_t, _camera_r, _camera_b );
	
    //If this light is ready to be drawn...
    if ( on_screen ) {
        
        surface_set_target( srf_light );
			
	        //Draw the light sprite
			shader_set( shd_pass_through );
	        draw_sprite_ext( sprite_index, image_index,    light_w_half, light_h_half,    1, 1, 0,    merge_colour( c_black, image_blend, image_alpha ), 1 );
			
	        //Magical projection!
			shader_set( shd_snap_vertex );
			matrix_set( matrix_view, matrix_build_lookat( x, y, light_w,   x, y, 0,   dsin( -image_angle ), -dcos( -image_angle ), 0 ) );
			matrix_set( matrix_projection, matrix_build_projection_perspective( image_xscale, image_yscale, 1, 16000 ) );
		
	        //Tell the GPU to render the shadow geometry
	        vertex_submit( other.vbf_static_shadows,  pr_trianglelist, -1 );
	        vertex_submit( other.vbf_dynamic_shadows, pr_trianglelist, -1 );
			
        surface_reset_target();
        
    }
}

gpu_set_cullmode( cull_noculling );
shader_reset();



///////////Create composite lighting surface
srf_lighting = surface_check( srf_lighting, _camera_w, _camera_h );
surface_set_target( srf_lighting );
	
    //Clear the surface with the ambient colour
    draw_clear( lighting_ambient_colour );
    
    //Use a cumulative blend mode to add lights together
	if ( LIGHTING_BM_MAX ) gpu_set_blendmode( bm_max ) else gpu_set_blendmode( bm_add );
    with ( obj_par_light ) {
		if ( on_screen ) {
			var _sin = -dsin( image_angle );
			var _cos =  dcos( image_angle );
			var _x = image_xscale*light_w_half*_cos - image_yscale*light_h_half*_sin;
			var _y = image_xscale*light_w_half*_sin + image_yscale*light_h_half*_cos;
			draw_surface_ext( srf_light, floor( x - _x - _camera_l + 0.5 ), floor( y - _y - _camera_t + 0.5 ), image_xscale, image_yscale, image_angle, c_white, 1 );
		}
	}
    gpu_set_blendmode( bm_normal );

surface_reset_target();



///////////Put the composite surface onto the screen
gpu_set_blendmode_ext( bm_dest_color, bm_zero );
draw_surface( srf_lighting, _camera_l, _camera_t );
gpu_set_blendmode( bm_normal );



///////////Reset prior GPU properties
//gpu_set_cullmode( _old_culling );
//matrix_set( matrix_world     , _old_world_matrix );
//matrix_set( matrix_view      , _old_view_matrix  );
//matrix_set( matrix_projection, _old_proj_matrix  );