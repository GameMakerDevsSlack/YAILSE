/// @param ambient_colour
/// @param self_lighting
/// @param culling
/// @param deferred
//
//  Initialises the necessary variables for a controller object to use the lighting system.
//  Should be called in one object per room.
//  Must be called before scr_lighting_build(), scr_lighting_draw(), and scr_lighting_end().
//
//  argument0: The ambient colour. Defaults to black. [Optional]
//  argument1: Whether or not to use self-lighting.   [Optional]
//  return: Nothing.
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

#macro LIGHTING_ZFAR 16000
#macro LIGHTING_Z_LIMIT 2000
#macro LIGHTING_DYNAMIC_INCLUSION 256
#macro LIGHTING_NEVER_DEFERRED false
#macro LIGHTING_REUSE_DYNAMIC_BUFFER true



//Assign the camera used to draw the lights
lighting_camera = argument0;

//Assign the ambient colour used for the darkest areas of the screen. This can be changed on the fly.
lighting_ambient_colour = argument1;

//If culling is switched on, shadows will only be cast from the rear faces of shadow casters.
//This requires careful object placement as not to create weird graphical glitches.
lighting_culling = argument2 ? cull_counterclockwise : cull_noculling;

//Switches from z-stencilling to deferred rendering.
lighting_deferred = argument3;



global.lighting_black_texture = sprite_get_texture( spr_lighting_black, 0 );
var _uvs = sprite_get_uvs( spr_lighting_black, 0 );
global.lighting_black_u = 0.5*( _uvs[0] + _uvs[2] );
global.lighting_black_v = 0.5*( _uvs[1] + _uvs[3] );



//Create vertex format for the shadow casting vertex buffers
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_colour();
vft_shadow_geometry = vertex_format_end();

vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_colour();
vertex_format_add_texcoord();
vft_3d_textured = vertex_format_end();



//Initialise variables used and updated in scr_lighting_build()
vbf_static_shadows = noone; //Vertex buffer describing the shadow casting geometry of the static objects.
vbf_dynamic_shadows = noone; //As above but for dynamic shadow casters. This is updated every step.
vbf_zbuffer_reset = noone; //This vertex buffer is used to reset the z-buffer for non-deferred rendering.
srf_lighting = noone; //Screen-space surface for final compositing of individual surfaces.