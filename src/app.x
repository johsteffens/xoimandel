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

include <locale.h>;

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
type GdkEventKey;
type GtkWidget;
type GtkFileChooser;
type GtkFileFilter;

//----------------------------------------------------------------------------------------------------------------------

stamp app_param_s =
{
    psp_s psp;
    color_map_s color_map;
}

//----------------------------------------------------------------------------------------------------------------------

stamp app_s =
{
    st_s => default_file;
    st_s => default_image_file;

    sz_t initial_width  = 400;
    sz_t initial_height = 400;

    hidden worker_s => worker;
    hidden bl_t shutting_down;

    private GtkWidget* window;            // main window
    private GtkWidget* rgba_image_widget; // widget displaying rgba_image (private)

    func int redraw( m @* o )
    {
        if( !o.shutting_down ) verbatim_C { gtk_widget_queue_draw( o->rgba_image_widget ); };
        = 0;
    };

    func xoimandel.redraw_now { o.redraw(); };
    func xoimandel.redraw_when_idle { verbatim_C { gdk_threads_add_idle( (int(*)(vd_t))app_s_redraw, o ) }; };

}

//----------------------------------------------------------------------------------------------------------------------

func (app_s) void reset_view( m@* o )
{
    if( !o.worker ) return;
    o.worker.reset_psp();
}

//----------------------------------------------------------------------------------------------------------------------

func (app_s) void set_param( m@* o, app_param_s* param )
{
    if( !o.worker ) return;
    o.worker.set_color_map( param.color_map );
    o.worker.set_psp( param.psp );
}

//----------------------------------------------------------------------------------------------------------------------

func (app_s) void get_param( m@* o, m app_param_s* param )
{
    if( !o.worker ) return;
    o.worker.get_color_map( param.color_map );
    o.worker.get_psp( param.psp );
}

//----------------------------------------------------------------------------------------------------------------------

func (app_s) void main_window_close_cb( m GtkWidget* win, m@* o )
{
    o.shutting_down = true;
    o.worker =< NULL;
}

//----------------------------------------------------------------------------------------------------------------------

func (app_s) gboolean drawable_draw_cb( m GtkWidget* drw, m cairo_t* cairo, m@* o )
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
    = FALSE;
}

//----------------------------------------------------------------------------------------------------------------------

func (app_s) gboolean drawable_configure_event_cb( GtkWidget* drw, GdkEventConfigure* event, m@* o )
{
    o.worker.resize( sz2i_s_of( event->width, event->height ) );
    = TRUE;
}

//----------------------------------------------------------------------------------------------------------------------

func (app_s) gboolean drawable_motion_notify_event_cb( GtkWidget* drw, GdkEventMotion* event, m@* o )
{
    if( event->state & GDK_BUTTON1_MASK )
    {
        o.worker.move_to( v2f_s_of( event->x, event->y ) );
        = TRUE;
    }
    = FALSE;
}

//----------------------------------------------------------------------------------------------------------------------

func (app_s) gboolean drawable_button_press_event_cb( GtkWidget* drw, GdkEventButton* event, m@* o )
{
    if( event->button == 1 )
    {
        o.worker.set_refpos( v2f_s_of( event->x, event->y ) );
        = TRUE;
    }
    = FALSE;
}

//----------------------------------------------------------------------------------------------------------------------

func (app_s) gboolean drawable_scroll_event_cb( GtkWidget* drw, GdkEventScroll* event, m@* o )
{
    v2f_s pos = v2f_s_of( event->x, event->y );
    if     ( event->direction == GDK_SCROLL_UP   ) o.worker.scale_up  ( pos );
    else if( event->direction == GDK_SCROLL_DOWN ) o.worker.scale_down( pos );
    else = FALSE;
    = TRUE;
}

//----------------------------------------------------------------------------------------------------------------------

func (app_s) gboolean menu_file_open_cb( m@* o )
{
    m GtkWidget* chooser = gtk_file_chooser_dialog_new
    (
        "File Open",
        GTK_WINDOW( o.window ),
        GTK_FILE_CHOOSER_ACTION_OPEN,
        "_Cancel",
        GTK_RESPONSE_CANCEL,
        "_Open",
        GTK_RESPONSE_ACCEPT,
        NULL
    );

    if( o.default_file )
    {
        gtk_file_chooser_set_filename( GTK_FILE_CHOOSER( chooser ), o.default_file.sc );
    }

    gint result = gtk_dialog_run( GTK_DIALOG( chooser ) );

    if( result == GTK_RESPONSE_ACCEPT )
    {
        sd_t file = gtk_file_chooser_get_filename( GTK_FILE_CHOOSER( chooser ) );
        m x_source* source = x_source_check_create_from_file( file )^;
        app_param_s^ param;
        if( x_btml_t_appears_valid( param._, source ) )
        {
            param.cast( m x_btml* ).from_source( source );
            o.set_param( param );
            o.default_file =< st_s_create_sc( file );
            g_free( file );
            gtk_window_set_title( GTK_WINDOW( o.window ), o.default_file.sc );
        }
        else
        {
            st_s^ msg.copy_fa( "File '#<sc_t>' is invalid.", file );
            m GtkWidget* dlg = gtk_message_dialog_new( GTK_WINDOW( o.window ), GTK_DIALOG_DESTROY_WITH_PARENT, GTK_MESSAGE_ERROR, GTK_BUTTONS_CLOSE, "%s", msg.sc );
            gtk_dialog_run( GTK_DIALOG( dlg ) );
            gtk_widget_destroy( dlg );
        }
    }

    gtk_widget_destroy( chooser );

    = TRUE;
}

//----------------------------------------------------------------------------------------------------------------------

func (app_s) gboolean menu_file_reload_cb( m@* o )
{
    if( o.default_file )
    {
        m x_source* source = x_source_check_create_from_file( o.default_file.sc )^;
        app_param_s^ param;
        if( x_btml_t_appears_valid( param._, source ) )
        {
            param.cast( m x_btml* ).from_source( source );
            o.set_param( param );
        }
        else
        {
            st_s^ msg.copy_fa( "File '#<sc_t>' is invalid.", o.default_file );
            m GtkWidget* dlg = gtk_message_dialog_new( GTK_WINDOW( o.window ), GTK_DIALOG_DESTROY_WITH_PARENT, GTK_MESSAGE_ERROR, GTK_BUTTONS_CLOSE, "%s", msg.sc );
            gtk_dialog_run( GTK_DIALOG( dlg ) );
            gtk_widget_destroy( dlg );
        }
        = TRUE;
    }
    else
    {
        = o.menu_file_open_cb();
    }
}

//----------------------------------------------------------------------------------------------------------------------

func (app_s) gboolean menu_file_save_cb( m@* o )
{
    if( o.default_file )
    {
        app_param_s^ param;
        o.get_param( param );
        param.cast( x_btml* ).to_file( o.default_file.sc );
        = TRUE;
    }
    else
    {
        = o.menu_file_save_as_cb();
    }
}

//----------------------------------------------------------------------------------------------------------------------

func (app_s) gboolean menu_file_save_as_cb( m@* o )
{
    m GtkWidget* chooser = gtk_file_chooser_dialog_new
    (
        "File Save As",
        GTK_WINDOW( o.window ),
        GTK_FILE_CHOOSER_ACTION_SAVE,
        "_Cancel",
        GTK_RESPONSE_CANCEL,
        "_Save",
        GTK_RESPONSE_ACCEPT,
        NULL
    );

    gtk_file_chooser_set_do_overwrite_confirmation( GTK_FILE_CHOOSER( chooser ), TRUE );

    if( o.default_file )
    {
        gtk_file_chooser_set_filename( GTK_FILE_CHOOSER( chooser ), o.default_file.sc );
    }

    gint result = gtk_dialog_run( GTK_DIALOG( chooser ) );

    if( result == GTK_RESPONSE_ACCEPT )
    {
        sd_t file_sd = gtk_file_chooser_get_filename( GTK_FILE_CHOOSER( chooser ) );
        st_s^ file.copy_sc( file_sd );
        g_free( file_sd );

        app_param_s^ param;
        o.get_param( param );
        param.cast( x_btml* ).to_file( file.sc );

        o.default_file =< file.clone();
        gtk_window_set_title( GTK_WINDOW( o.window ), o.default_file.sc );
    }

    gtk_widget_destroy( chooser );

    = TRUE;
}

//----------------------------------------------------------------------------------------------------------------------

func (app_s) gboolean menu_file_save_image_as_cb( m@* o )
{
    m GtkWidget* chooser = gtk_file_chooser_dialog_new
    (
        "File Save As",
        GTK_WINDOW( o.window ),
        GTK_FILE_CHOOSER_ACTION_SAVE,
        "_Cancel",
        GTK_RESPONSE_CANCEL,
        "_Save",
        GTK_RESPONSE_ACCEPT,
        NULL
    );

    if( o.default_image_file )
    {
        gtk_file_chooser_set_filename( GTK_FILE_CHOOSER( chooser ), o.default_image_file.sc );
    }

    gtk_file_chooser_set_do_overwrite_confirmation( GTK_FILE_CHOOSER( chooser ), TRUE );

    {
        m GtkFileFilter* filter = gtk_file_filter_new();
        gtk_file_filter_set_name( filter, "PNM Format (*.pnm)" );
        gtk_file_filter_add_pattern( filter, "*.pnm" );
        gtk_file_chooser_add_filter( GTK_FILE_CHOOSER( chooser ), filter );
    }

    gint result = gtk_dialog_run( GTK_DIALOG( chooser ) );

    if( result == GTK_RESPONSE_ACCEPT )
    {
        sd_t file_sd = gtk_file_chooser_get_filename( GTK_FILE_CHOOSER( chooser ) );
        st_s^ file.copy_sc( file_sd );
        g_free( file_sd );

        rgba_image_s* image = o.worker.get_draw_image();
        m $* img_u2 = bcore_img_u2_s!^;
        img_u2.set_size( image.sz.height, image.sz.width );
        for( sz_t j = 0; j < image.sz.height; j++ )
        {
            for( sz_t i = 0; i < image.sz.width; i++ )
            {
                rgba_s* rgba = image.get_pix( i, j );
                img_u2.set_rgb( j, i, rgba.r, rgba.g, rgba.b );
            }
        }

        if
        (
            !sc_t_equal( bcore_file_extension( file.sc ), "pnm" ) &&
            !sc_t_equal( bcore_file_extension( file.sc ), "PNM" )
        )
        {
            st_s^ msg.copy_fa
            (
                "Currently only the PNM Image-Format is supported.\n"
                "Please add the extension '.pnm' or '.PNM' to your file name.\n"
                "Example: #<sc_t>.pnm\n",
                bcore_file_name( file.sc )
            );
            m GtkWidget* dlg = gtk_message_dialog_new( GTK_WINDOW( o.window ), GTK_DIALOG_DESTROY_WITH_PARENT, GTK_MESSAGE_ERROR, GTK_BUTTONS_CLOSE, "%s", msg.sc );
            gtk_dialog_run( GTK_DIALOG( dlg ) );
            gtk_widget_destroy( dlg );
        }
        else
        {
            img_u2.pnm_to_file( file.sc );
            o.default_image_file =< file.clone();
        }
    }

    gtk_widget_destroy( chooser );

    = TRUE;
}

//----------------------------------------------------------------------------------------------------------------------

func (app_s) gboolean menu_about_cb( m@* o )
{
    st_s^ msg;
    msg.push_fa( "XoiMandel\n" );
    msg.push_fa( "GTK+ 3 based application for zooming\n" );
    msg.push_fa( "into the Mandelbrot-Set.\n" );
    msg.push_fa( "\n" );
    msg.push_fa( "Source: https://github.com/johsteffens/xoimandel\n" );
    msg.push_fa( "Author: Johannes Steffens\n" );
    msg.push_fa( "License: GPL Version 3.\n" );

    m GtkWidget* dlg = gtk_message_dialog_new( GTK_WINDOW( o.window ), GTK_DIALOG_DESTROY_WITH_PARENT, GTK_MESSAGE_INFO, GTK_BUTTONS_CLOSE, "%s", msg.sc );

    gtk_dialog_run( GTK_DIALOG( dlg ) );
    gtk_widget_destroy( dlg );
    = TRUE;
}

//----------------------------------------------------------------------------------------------------------------------

func (app_s) gboolean win_key_press_event_cb( GtkWidget* win, GdkEventKey* event, m@* o )
{
    if( event->state == GDK_CONTROL_MASK && event->keyval == GDK_KEY_s )
    {
        = app_s_menu_file_save_cb( o );
    }
    else if( event->state == GDK_CONTROL_MASK && event->keyval == GDK_KEY_r )
    {
        = app_s_menu_file_reload_cb( o );
    }
    else
    {
        = FALSE;
    }
}

//----------------------------------------------------------------------------------------------------------------------

func (app_s) void activate_gtk_app( m GtkApplication* gtk_app, m@* o )
{
    m GtkWidget* win = gtk_application_window_new( gtk_app );
    gtk_window_set_title( GTK_WINDOW( win ), "XoiMandel" );
    m GtkWidget* win_vbox = gtk_box_new( GTK_ORIENTATION_VERTICAL, 0 );
    gtk_container_add( GTK_CONTAINER( win ), win_vbox );

    m GtkWidget* menu_box = gtk_box_new( GTK_ORIENTATION_HORIZONTAL, 0 );
    gtk_container_add( GTK_CONTAINER( win_vbox ), menu_box );
    gtk_widget_show( menu_box );

    m GtkWidget* menu_bar = gtk_menu_bar_new();
    gtk_box_pack_start( GTK_BOX( menu_box ), menu_bar, TRUE, TRUE, 0 );
    gtk_widget_show( menu_bar );

    {
        m GtkWidget* item = gtk_menu_item_new_with_label( "File" );
        gtk_menu_shell_append( GTK_MENU_SHELL( menu_bar ), item );
        m GtkWidget* menu = gtk_menu_new();
        gtk_menu_item_set_submenu( GTK_MENU_ITEM( item ), menu );
        {
            m GtkWidget* item = gtk_menu_item_new_with_label( "Open" );
            gtk_menu_shell_append( GTK_MENU_SHELL( menu ), item );
            g_signal_connect_swapped( item, "activate", G_CALLBACK( app_s_menu_file_open_cb ), o );
            gtk_widget_show( item );
        }
        {
            m GtkWidget* item = gtk_menu_item_new_with_label( "Reload (Ctrl+R)" );
            gtk_menu_shell_append( GTK_MENU_SHELL( menu ), item );
            g_signal_connect_swapped( item, "activate", G_CALLBACK( app_s_menu_file_reload_cb ), o );
            gtk_widget_show( item );
        }
        {
            m GtkWidget* item = gtk_menu_item_new_with_label( "Save (Ctrl+S)" );
            gtk_menu_shell_append( GTK_MENU_SHELL( menu ), item );
            g_signal_connect_swapped( item, "activate", G_CALLBACK( app_s_menu_file_save_cb ), o );
            gtk_widget_show( item );
        }
        {
            m GtkWidget* item = gtk_menu_item_new_with_label( "Save As" );
            gtk_menu_shell_append( GTK_MENU_SHELL( menu ), item );
            g_signal_connect_swapped( item, "activate", G_CALLBACK( app_s_menu_file_save_as_cb ), o );
            gtk_widget_show( item );
        }
        {
            m GtkWidget* item = gtk_menu_item_new_with_label( "Save Image As" );
            gtk_menu_shell_append( GTK_MENU_SHELL( menu ), item );
            g_signal_connect_swapped( item, "activate", G_CALLBACK( app_s_menu_file_save_image_as_cb ), o );
            gtk_widget_show( item );
        }
        {
            m GtkWidget* item = gtk_menu_item_new_with_label( "Quit" );
            gtk_menu_shell_append( GTK_MENU_SHELL( menu ), item );
            g_signal_connect_swapped( item, "activate", G_CALLBACK( gtk_window_close ), win );
            gtk_widget_show( item );
        }
    }

    {
        m GtkWidget* item = gtk_menu_item_new_with_label( "View" );
        gtk_menu_shell_append( GTK_MENU_SHELL( menu_bar ), item );
        m GtkWidget* menu = gtk_menu_new();
        gtk_menu_item_set_submenu( GTK_MENU_ITEM( item ), menu );
        {
            m GtkWidget* item = gtk_menu_item_new_with_label( "Reset" );
            gtk_menu_shell_append( GTK_MENU_SHELL( menu ), item );
            g_signal_connect_swapped( item, "activate", G_CALLBACK( app_s_reset_view ), o );
            gtk_widget_show( item );
        }
    }

    {
        m GtkWidget* item = gtk_menu_item_new_with_label( "Help" );
        gtk_menu_shell_append( GTK_MENU_SHELL( menu_bar ), item );
        m GtkWidget* menu = gtk_menu_new();
        gtk_menu_item_set_submenu( GTK_MENU_ITEM( item ), menu );
        {
            m GtkWidget* item = gtk_menu_item_new_with_label( "About" );
            gtk_menu_shell_append( GTK_MENU_SHELL( menu ), item );
            g_signal_connect_swapped( item, "activate", G_CALLBACK( app_s_menu_about_cb ), o );
            gtk_widget_show( item );
        }
    }

    m GtkWidget* frm = gtk_frame_new( NULL );
    gtk_frame_set_shadow_type( GTK_FRAME( frm ), GTK_SHADOW_ETCHED_IN );

    gtk_box_pack_end( GTK_BOX( win_vbox ), frm, TRUE, TRUE, 0 );

    m GtkWidget* drawing_area = gtk_drawing_area_new();
    gtk_widget_set_size_request( drawing_area, o.initial_width, o.initial_height );
    gtk_container_add( GTK_CONTAINER( frm ), drawing_area );

    o.worker =< worker_s!;
    o.window = win;
    o.rgba_image_widget = drawing_area;
    o.worker.parent = o;

    g_signal_connect( win, "destroy", G_CALLBACK( app_s_main_window_close_cb ), o );
    gtk_container_set_border_width( GTK_CONTAINER( frm ), 4 );

    g_signal_connect( drawing_area, "draw", G_CALLBACK( app_s_drawable_draw_cb ), o );
    g_signal_connect( drawing_area, "configure-event", G_CALLBACK( app_s_drawable_configure_event_cb ), o ); // resize
    g_signal_connect( drawing_area, "motion-notify-event", G_CALLBACK( app_s_drawable_motion_notify_event_cb ), o ); // mouse motion
    g_signal_connect( drawing_area, "button-press-event",  G_CALLBACK( app_s_drawable_button_press_event_cb ), o ); // mouse button
    g_signal_connect( drawing_area, "scroll-event",  G_CALLBACK( app_s_drawable_scroll_event_cb ), o ); // mouse button

    g_signal_connect( win, "key-press-event",  G_CALLBACK( app_s_win_key_press_event_cb ), o ); // keyboard
    gtk_widget_set_events( drawing_area, gtk_widget_get_events( drawing_area ) | GDK_BUTTON_PRESS_MASK | GDK_POINTER_MOTION_MASK | GDK_SCROLL_MASK );

    gtk_widget_show_all( win );
}

//----------------------------------------------------------------------------------------------------------------------

func (app_s) int run( m@* o, int argc, m char** argv )
{
    m GtkApplication* gtk_app = gtk_application_new( "xoimandel.johsteffens.de", G_APPLICATION_FLAGS_NONE );
    g_signal_connect( gtk_app, "activate", G_CALLBACK( app_s_activate_gtk_app ), o );
    = g_application_run( G_APPLICATION( gtk_app ), argc, argv );
}

//----------------------------------------------------------------------------------------------------------------------

stamp c_args_s = x_array { sc_t []; };

func x_inst.main
{
    gtk_disable_setlocale();
    setlocale( LC_ALL, "C" );

    c_args_s^ c_args.set_size( args.size );
    for( sz_t i = 0; i < args.size; i++ ) c_args.[ i ] = args.[ i ].sc;

    m app_s* app = app_s!^;
    = ( s2_t )app.run( ( int )c_args.size, ( char** )c_args.data );
}

//----------------------------------------------------------------------------------------------------------------------

/**********************************************************************************************************************/

