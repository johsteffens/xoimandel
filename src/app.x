/** Author and Copyright 2021 Johannes Bernhard Steffens
 *
 *  This file is part of XOIMANDEL.
 *
 *  XOIMANDEL is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  XOIMANDEL is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with XOIMANDEL.  If not, see <https://www.gnu.org/licenses/>.
 */

/**********************************************************************************************************************/

// active xoico waivers for this file (see xoimandel_app.cfg)
// waive_unknown_member_variable
// waive_function_in_untraced_context
// waive_unknown_identifier

// We do not waive unknown types because xoico should take notice of variable declarations.
// This requires declaring external types explicitly...
type GtkApplication;
type cairo_t;
type gboolean;
type cairo_surface_t;
type GdkEventConfigure;
type GdkEventMotion;
type GdkEventButton;
type GdkEventScroll;
type GtkWidget;

//----------------------------------------------------------------------------------------------------------------------

stamp app_s =
{
    hidden worker_s => worker;
    hidden bl_t shutting_down;
    private GtkWidget* rgba_image_widget; // widget displaying rgba_image (private)

    func (int redraw( m @* o )) =
    {
        if( !o.shutting_down ) verbatim_C { gtk_widget_queue_draw( o->rgba_image_widget ); };
        return 0;
    };

    func xoimandel.redraw_now = { o.redraw(); };
    func xoimandel.redraw_when_idle = { verbatim_C { gdk_threads_add_idle( (int(*)(vd_t))app_s_redraw, o ) }; };
};

//----------------------------------------------------------------------------------------------------------------------

func (app_s) (void main_window_close_cb( m GtkWidget* win, m@* o )) =
{
    o.shutting_down = true;
    o.worker =< NULL;
};

//----------------------------------------------------------------------------------------------------------------------

func (app_s) (gboolean drawable_draw_cb( m GtkWidget* drw, m cairo_t* cairo, m@* o )) =
{
    rgba_image_s* image = o.worker.get_draw_image();

    if( image )
    {
        /// this function only references image->data but does not copy or modify it
        m cairo_surface_t* surface = cairo_image_surface_create_for_data
        (
            ( u0_t* )image->data,
            CAIRO_FORMAT_RGB24,
            image->sz.width,
            image->sz.height,
            image->sz.width * 4
        );

        if( surface )
        {
            cairo_set_source_surface( cairo, surface, 0, 0 );
            cairo_paint( cairo );
        }
        cairo_surface_destroy( surface );
    }
    return FALSE;
};

//----------------------------------------------------------------------------------------------------------------------

func (app_s) (gboolean drawable_configure_event_cb( GtkWidget* drw, GdkEventConfigure* event, m@* o )) =
{
    o.worker.resize( sz2i_s_of( event->width, event->height ) );
    return TRUE;
};

//----------------------------------------------------------------------------------------------------------------------

func (app_s) (gboolean drawable_motion_notify_event_cb( GtkWidget* drw, GdkEventMotion* event, m@* o )) =
{
    if( event->state & GDK_BUTTON1_MASK )
    {
        o.worker.move_to( v2f_s_of( event->x, event->y ) );
        return TRUE;
    }
    return FALSE;
};

//----------------------------------------------------------------------------------------------------------------------

func (app_s) (gboolean drawable_button_press_event_cb( GtkWidget* drw, GdkEventButton* event, m@* o )) =
{
    if( event->button == 1 )
    {
        o.worker.set_refpos( v2f_s_of( event->x, event->y ) );
        return TRUE;
    }
    return FALSE;
};

//----------------------------------------------------------------------------------------------------------------------

func (app_s) (gboolean drawable_scroll_event_cb( GtkWidget* drw, GdkEventScroll* event, m@* o )) =
{
    v2f_s pos = v2f_s_of( event->x, event->y );
    if     ( event->direction == GDK_SCROLL_UP   ) o.worker.scale_up  ( pos );
    else if( event->direction == GDK_SCROLL_DOWN ) o.worker.scale_down( pos );
    else return FALSE;
    return TRUE;
};

//----------------------------------------------------------------------------------------------------------------------

func (app_s) (void activate_gtk_app( m GtkApplication* gtk_app, m@* o )) =
{
    m GtkWidget* win = gtk_application_window_new( gtk_app );
    gtk_window_set_title( GTK_WINDOW( win ), "XOIMANDEL" );

    m GtkWidget* frm = gtk_frame_new( NULL );
    gtk_frame_set_shadow_type( GTK_FRAME( frm ), GTK_SHADOW_ETCHED_IN );
    gtk_container_add( GTK_CONTAINER( win ), frm );

    m GtkWidget* drw = gtk_drawing_area_new();
    gtk_widget_set_size_request( drw, 600, 600 );
    gtk_container_add( GTK_CONTAINER( frm ), drw );

    o.worker =< worker_s!;
    o.rgba_image_widget = drw;
    o.worker.parent = o;

    g_signal_connect( win, "destroy", G_CALLBACK( app_s_main_window_close_cb ), o );
    gtk_container_set_border_width( GTK_CONTAINER( win ), 4 );

    g_signal_connect( drw, "draw", G_CALLBACK( app_s_drawable_draw_cb ), o );
    g_signal_connect( drw, "configure-event", G_CALLBACK( app_s_drawable_configure_event_cb ), o ); // resize
    g_signal_connect( drw, "motion-notify-event", G_CALLBACK( app_s_drawable_motion_notify_event_cb ), o ); // mouse motion
    g_signal_connect( drw, "button-press-event",  G_CALLBACK( app_s_drawable_button_press_event_cb ), o ); // mouse button
    g_signal_connect( drw, "scroll-event",  G_CALLBACK( app_s_drawable_scroll_event_cb ), o ); // mouse button

    gtk_widget_set_events( drw, gtk_widget_get_events( drw ) | GDK_BUTTON_PRESS_MASK | GDK_POINTER_MOTION_MASK | GDK_SCROLL_MASK );

    gtk_widget_show_all( win );
};

//----------------------------------------------------------------------------------------------------------------------

func (app_s) (int run( m@* o, int argc, m char** argv )) =
{
    m GtkApplication* gtk_app = gtk_application_new( "mandel.johsteffens.de", G_APPLICATION_FLAGS_NONE );
    g_signal_connect( gtk_app, "activate", G_CALLBACK( app_s_activate_gtk_app ), o );
    return g_application_run( G_APPLICATION( gtk_app ), argc, argv );
};

//----------------------------------------------------------------------------------------------------------------------

stamp c_args_s = x_array { sc_t []; };

func x_inst.main =
{
    c_args_s^ c_args.set_size( args.size );
    for( sz_t i = 0; i < args.size; i++ ) c_args.[ i ] = args.[ i ].sc;

    m app_s* app = app_s!^;
    return ( s2_t )app.run( ( int )c_args.size, ( char** )c_args.data );
};

//----------------------------------------------------------------------------------------------------------------------

/**********************************************************************************************************************/

