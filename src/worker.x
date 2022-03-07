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
/// worker

type GtkWidget;

/// tell window manager to redraw
feature void redraw_now( m @* o );
feature void redraw_when_idle( m @* o );

//----------------------------------------------------------------------------------------------------------------------

stamp worker_s =
{
    orbit_s orbit;
    sz2i_s image_sz;

    x_mutex_s mutex;
    x_thread_s thread;

    psp_s depth_image_buffered_psp;
    psp_s depth_image_released_psp;
    bl_t  depth_image_update;
    bl_t  depth_image_thread_busy;

    depth_image_s => depth_image_buffered;
    depth_image_s => depth_image_released;

    /// image for drawing
    psp_s        draw_psp;
    rgba_image_s rgba_image_draw;

    color_map_s color_map;

    f3_t scale_step;

    private aware :* parent; // parent implements above features

    bl_t shutting_down;

    //------------------------------------------------------------------------------------------------------------------

    func (void reset( m@* o ));
    func (void setup( m@* o ));

    func bcore_inst_call.init_x { o.setup(); };
    func bcore_inst_call.down_e;
};

//----------------------------------------------------------------------------------------------------------------------

func (worker_s) reset
{
    o.depth_image_buffered_psp = psp_s_of( v2f_s_of( 0, 0 ), 0.008, v2f_s_of(  -0.5, 0 ) );
    o.draw_psp                 = psp_s_of( v2f_s_of( 0, 0 ), 1 , v2f_s_of( 0, 0 ) );
    o.depth_image_released_psp = psp_s_of_one();
    o.scale_step   = 1.1;
};

//----------------------------------------------------------------------------------------------------------------------

func (worker_s) setup
{
    o.reset();
    o.depth_image_buffered = depth_image_s!;
    o.depth_image_released = depth_image_s!;
};

//----------------------------------------------------------------------------------------------------------------------

func (worker_s) down_e
{
    o.mutex.lock();
    o.shutting_down = true;
    o.mutex.unlock();
    o.thread.join();
};

//----------------------------------------------------------------------------------------------------------------------

stamp block_thread_s =
{
    v2i_s  p;
    sz2i_s sz;
    psp_s  psp;
    hidden depth_image_s* image;
    hidden orbit_s* orbit;

    x_thread_s thread;

    func (o of( m @* o, v2i_s p, sz2i_s sz, psp_s  psp, m depth_image_s* image, orbit_s* orbit ))
    {
        o.p = p;
        o.sz = sz;
        o.psp = psp;
        o.image = image;
        o.orbit = orbit.cast( m$* );
        o.thread.call_m_thread_func( o );
        return o;
    };

    func (o join(m@*o) ) { o.thread.join(); return o; };

    func x_thread.m_thread_func
    {
        sz_t x0 = sz_max( o.p.x, 0 );
        sz_t x1 = sz_min( o.p.x + o.sz.width, o.image.sz.width );
        sz_t y0 = sz_max( o.p.y, 0 );
        sz_t y1 = sz_min( o.p.y + o.sz.height, o.image.sz.height );
        for( sz_t j = y0; j < y1; j++ )
        {
            for( sz_t i = x0; i < x1; i++ )
            {
                o.image.set_pix( i, j, o.orbit.escape_time( o.psp.map( :pos_from_idx( o.image.sz, v2i_s_of( i, j ) ) ) ) );
            }
        }
        return NULL;
    };
};

//----------------------------------------------------------------------------------------------------------------------

stamp block_thread_pool_s = x_array { block_thread_s => []; };

//----------------------------------------------------------------------------------------------------------------------

func (worker_s) x_thread.m_thread_func
{
    o.mutex.create_lock()^;
    o.depth_image_thread_busy = true;

    while( o.depth_image_update && !o.shutting_down )
    {
        o.depth_image_update = false;
        o.depth_image_buffered_psp = o.depth_image_buffered_psp.mul( o.draw_psp );
        o.depth_image_released_psp = o.depth_image_released_psp.mul( o.draw_psp );
        o.draw_psp.set_one_at( o.draw_psp.p1 );

        bl_t redraw = true;
        {
            $ psp = o.depth_image_buffered_psp;
            o.mutex.create_unlock()^;
            if( !o.image_sz.equal( o.depth_image_buffered.sz ) ) o.depth_image_buffered.set_sz( o.image_sz );
            m $* image = o.depth_image_buffered;

            sz_t block_size = 64;

            block_thread_pool_s^ pool;
            for( sz_t j = 0; j < image.sz.height; j += block_size )
            {
                for( sz_t i = 0; i < image.sz.width; i += block_size )
                {
                    pool.push_d( block_thread_s!.of( v2i_s_of( i, j ), sz2i_s_of( block_size, block_size ), psp, image, o.orbit ) );
                }
            }
            pool.clear();

//            o.mutex.create_lock()^;
//            if( o.shutting_down || o.depth_image_update )
//            {
//                redraw = false;
//                break;
//            }
        }

        if( redraw )
        {
            o.depth_image_buffered.equalize_histogram();
            // swap: depth_image_buffered <-> depth_image_released
            m$* tmp = o.depth_image_buffered;
            o.depth_image_buffered = o.depth_image_released;
            o.depth_image_released = tmp;
            o.depth_image_released_psp = psp_s_of_one();

            o.mutex.unlock();
            if( o.parent ) o.parent.redraw_when_idle();
            o.mutex.lock();
        }
    }

    o.depth_image_thread_busy = false;
    return NULL;
};

//----------------------------------------------------------------------------------------------------------------------

func (worker_s) (void depth_image_update( m @* o ))
{
    o.mutex.lock();
    o.depth_image_update = true;
    bl_t busy = o.depth_image_thread_busy;
    o.mutex.unlock();
    if( !busy ) o.thread.call_m_thread_func( o );
};

//----------------------------------------------------------------------------------------------------------------------

func (worker_s) (void image_update( m @* o ))
{
    o.parent.redraw_now();
    o.depth_image_update();
};

//----------------------------------------------------------------------------------------------------------------------

func (worker_s) (void resize( m @* o, sz2i_s sz ))
{
    o.mutex.lock();
    o.image_sz = sz;
    o.mutex.unlock();
    o.image_update();
};

//----------------------------------------------------------------------------------------------------------------------

func (worker_s) (void set_refpos( m @* o, v2f_s pos_pointer ))
{
    o.mutex.lock();
    v2f_s refpos_surface = :pos_from_fdx( o.image_sz, pos_pointer );
    o.draw_psp.set_pos( refpos_surface );
    o.mutex.unlock();
};

//----------------------------------------------------------------------------------------------------------------------

func (worker_s) (void get_psp( m @* o, m psp_s* psp ))
{
    o.mutex.lock();
    psp.copy( o.depth_image_buffered_psp );
    o.mutex.unlock();
};

//----------------------------------------------------------------------------------------------------------------------

func (worker_s) (void set_psp( m @* o, psp_s* psp ))
{
    o.mutex.lock();
    o.reset();
    o.depth_image_buffered_psp.copy( psp );
    o.depth_image_released_psp = psp_s_of_one();
    o.draw_psp = psp_s_of_one();
    o.mutex.unlock();
    o.image_update();
};

//----------------------------------------------------------------------------------------------------------------------

func (worker_s) (void reset_psp( m @* o ))
{
    o.mutex.lock();
    o.reset();
    o.mutex.unlock();
    o.image_update();
};

//----------------------------------------------------------------------------------------------------------------------

func (worker_s) (void get_color_map( m @* o, m color_map_s* map ))
{
    o.mutex.lock();
    map.copy( o.color_map );
    o.mutex.unlock();
};

//----------------------------------------------------------------------------------------------------------------------

func (worker_s) (void set_color_map( m @* o, color_map_s* map ))
{
    o.mutex.lock();
    o.color_map.copy( map );
    o.mutex.unlock();
    o.image_update();
};

//----------------------------------------------------------------------------------------------------------------------

func (worker_s) (void move_to( m @* o, v2f_s pos_pointer ))
{
    v2f_s refpos_surface = :pos_from_fdx( o.image_sz, pos_pointer );
    o.mutex.lock();
    o.draw_psp.p1 = refpos_surface;
    o.mutex.unlock();
    o.image_update();
};

//----------------------------------------------------------------------------------------------------------------------

func (worker_s) (void scale_up( m@* o, v2f_s pos_pointer ))
{
    o.set_refpos( pos_pointer );
    o.mutex.lock();
    o.draw_psp.s *= 1.0 / o.scale_step;
    o.mutex.unlock();
    o.image_update();
};

//----------------------------------------------------------------------------------------------------------------------

func (worker_s) (void scale_down( m@* o, v2f_s pos_pointer ))
{
    o.set_refpos( pos_pointer );
    o.mutex.lock();
    o.draw_psp.s *= o.scale_step;
    o.mutex.unlock();
    o.image_update();
};

//----------------------------------------------------------------------------------------------------------------------

func (worker_s) (rgba_image_s* get_draw_image( m@* o ))
{
    o.mutex.lock();
    psp_s psp = o.depth_image_released_psp.mul( o.draw_psp );
    if( !o.image_sz.equal( o.rgba_image_draw.sz ) ) o.rgba_image_draw.set_sz( o.image_sz );

    o.rgba_image_draw.fill_cub_from_depth_image( o.depth_image_released, o.color_map, psp );
    o.mutex.unlock();

    return o.rgba_image_draw;
};

//----------------------------------------------------------------------------------------------------------------------

/**********************************************************************************************************************/

