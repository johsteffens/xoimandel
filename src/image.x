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
/// depth_image

//----------------------------------------------------------------------------------------------------------------------

stamp u3_range_s = obliv  x_inst { u3_t min; u3_t max; };

stamp depth_image_s = x_array
{
    u3_t []; sz2i_s sz;
    func (o set_sz( m@* o, sz2i_s sz )) = { o.set_size( sz.width * sz.height ); o.sz = sz; return o; };
    func (u3_t get_pix( @* o, sz_t x, sz_t y )) = { return o.sz.inside( x, y ) ? o->data[ y * o->sz.width + x ] : 0; };
    func (void set_pix( m@* o, sz_t x, sz_t y, u3_t v )) = { if( o.sz.inside( x, y ) ) o->data[ y * o->sz.width + x ] = v; };
    func (u3_t get_max( const depth_image_s* o )) = { u3_t r =  0; foreach( u3_t v in o ) r = v > r ? v : r; return r; };
    func (u3_t get_min( const depth_image_s* o )) = { u3_t r = -1; foreach( u3_t v in o ) r = v < r ? v : r; return r; };
    func (u3_t pix_from_idx( @* o, v2i_s* idx )) = { return o.get_pix( idx.x, idx.y ); };

    func (u3_range_s get_range( const depth_image_s* o )) =
    {
        u3_range_s r; r.max = 0; r.min = -1;
        foreach( u3_t v in o )
        {
            r.min = v < r.min ? v : r.min;
            r.max = v > r.max ? v : r.max;
        }
        return r;
    };
};

//----------------------------------------------------------------------------------------------------------------------

/// cubic spline warping optimized for a pixel-row
func (depth_image_s) (void fill_cub_row_from_pos( @* o, v2f_s pos, f3_t dx, m u3_t* row, sz_t size )) =
{
    if( o->sz.width * o->sz.height == 0 ) return;
    v2f_s fdx = :fdx_from_pos( o.sz, pos );

    const f3_t pow_2_32 = verbatim_C{ pow( 2.0, 32 ) };
    s3_t x_idx0_fx = :f3_rint( ( fdx.x - 0.5 ) * pow_2_32 );
    s3_t x_stp_fx  = :f3_rint( dx * pow_2_32 );

    s3_t y_idx_fx  = :f3_rint( ( fdx.y - 0.5 ) * pow_2_32 );
    uz_t y_idx = ( y_idx_fx >> 32 ) - 1;

    s3_t y  = ( y_idx_fx >> 26 ) & ( ( 1 << 6 ) - 1 );
    s3_t y0 =             1 << 18;
    s3_t y1 = ( y         ) << 12;
    s3_t y2 = ( y * y     ) << 6;
    s3_t y3 = ( y * y * y );

    s3_t yf_arr[ 4 ] =
    {
        (     -y3 + 2 * y2 - y1      ),
        (  3 * y3 - 5 * y2 +  2 * y0 ),
        ( -3 * y3 + 4 * y2 + y1      ),
        (      y3 -     y2           )
    };


    sz_t width = o->sz.width;
    for( sz_t i = 0; i < size; i++ ) row[ i ] = 0;

    for( sz_t j = 0; j < 4; j++ )
    {
        s3_t yf = yf_arr[ j ];
        if( y_idx < o->sz.height )
        {
            u3_t* dp = o.data + y_idx * width;
            s3_t x_idx_fx = x_idx0_fx;
            for( sz_t i = 0; i < size; i++ )
            {
                uz_t x_idx = ( x_idx_fx >> 32 ) - 1;

                s3_t x  = ( x_idx_fx >> 26 ) & ( ( 1 << 6 ) - 1 );
                s3_t x0 =             1 << 18;
                s3_t x1 = ( x         ) << 12;
                s3_t x2 = ( x * x     ) <<  6;
                s3_t x3 = ( x * x * x );

                s3_t v;
                v  = x_idx < width ? dp[ x_idx ] * (     -x3 + 2 * x2 - x1      ) : 0;
                x_idx++;
                v += x_idx < width ? dp[ x_idx ] * (  3 * x3 - 5 * x2 +  2 * x0 ) : 0;
                x_idx++;
                v += x_idx < width ? dp[ x_idx ] * ( -3 * x3 + 4 * x2 + x1      ) : 0;
                x_idx++;
                v += x_idx < width ? dp[ x_idx ] * (      x3 -     x2           ) : 0;

                row[ i ] += ( ( v + ( 1 << 17 ) ) >> 18 ) * yf;
                x_idx_fx += x_stp_fx;
            }
        }
        y_idx++;
    }

    for( sz_t i = 0; i < size; i++ )
    {
        s3_t v = row[ i ];
        row[ i ] = ( v >= 0 ) ? ( v + ( 1 << 19 ) ) >> 20 : 0;
    }
};

//----------------------------------------------------------------------------------------------------------------------

stamp :hist_s = x_array { f3_t []; };
func (depth_image_s) (void equalize_histogram( @* o )) =
{
    u3_range_s range = o.get_range();

    uz_t shr = 0;
    uz_t diff = range.max - range.min;
    while( ( diff >> shr ) > 500000 ) shr++;

    :hist_s^ hist.set_size( ( diff >> shr ) + 1 );

    for( sz_t j = 0; j < o.sz.height; j++ )
    {
        for( sz_t i = 0; i < o.sz.width; i++ )
        {
            u3_t v = o.[ i + j * o.sz.width ];
            f3_t x = ( f3_t ) ( i - ( o.sz.width  >> 1 ) ) / ( o.sz.width  >> 1 );
            f3_t y = ( f3_t ) ( j - ( o.sz.height >> 1 ) ) / ( o.sz.height >> 1 );
            f3_t w = :f3_exp( - ( x * x + y * y ) * 4 );
            if( v > 0 ) hist.[ ( v - range.min ) >> shr ] += w;
        }
    }

    f3_t hsum = 0;
    foreach( m f3_t* v in hist ) *v = ( hsum += *v );

    u3_t max_out = 65536;

    f3_t f = max_out.cast( f3_t ) / ( ( hsum > 0 ) ? hsum : 1 );

    foreach( m u3_t* v in o ) *v = hist.[ ( *v - range.min ) >> shr ] * f;
};

//----------------------------------------------------------------------------------------------------------------------

/**********************************************************************************************************************/
/// color

//----------------------------------------------------------------------------------------------------------------------

func (u0_t v_to_u0( f3_t v )) = { return ( v <= 0 ) ? 0.0 : ( v >= 1.0 ) ? 255 : v * 255; };

stamp color_s = obliv x_inst
{
    f3_t r; f3_t g; f3_t b;

    func (u0_t r_to_u0( @* o )) = { return :v_to_u0( o.r ); };
    func (u0_t g_to_u0( @* o )) = { return :v_to_u0( o.g ); };
    func (u0_t b_to_u0( @* o )) = { return :v_to_u0( o.b ); };
};

//----------------------------------------------------------------------------------------------------------------------

stamp color_map_s =
{
    func (color_s map( @* o, u3_t val )) =
    {
        color_s c;
        f3_t v = ( f3_t )( val ) / 65536;
        c.b = :f3_sin( :f3_pow( v, 5.0 ) * 3 * :f3_pi() ) * ( 1 - v ) + :f3_pow( v, 1.0 ) * v;
        c.g = :f3_sin( :f3_pow( v, 2.0 ) * 1 * :f3_pi() ) * ( 1 - v ) + :f3_pow( v, 3.0 ) * v;
        c.r = :f3_sin( :f3_pow( v, 1.0 ) * 2 * :f3_pi() ) * ( 1 - v ) + :f3_pow( v, 4.0 ) * v;
        return c;
    };
};

//----------------------------------------------------------------------------------------------------------------------

/**********************************************************************************************************************/
/// rgba_image

//----------------------------------------------------------------------------------------------------------------------

stamp rgba_s = obliv x_inst
{
    u0_t b; u0_t g; u0_t r; u0_t a;
    func (u2_t u2( @*o )) = { return o.cast( u2_t* ).0; };
    func (void set_u2( m@*o, u2_t v )) = { o.cast( m u2_t* ).0 = v; };
};

//----------------------------------------------------------------------------------------------------------------------

stamp rgba_image_s = x_array
{
    rgba_s [];
    sz2i_s sz;

    func (o set_sz( m@* o, sz2i_s sz )) = { o.set_size( sz.width * sz.height ); o.sz = sz; return o; };
    func (u2_t get_pix_u2( @* o, sz_t x, sz_t y )) = { return o.sz.inside( x, y ) ? o.data[ y * o->sz.width + x ].u2() : 0; };
    func (void set_pix_u2( m@* o, sz_t x, sz_t y, u2_t v )) = { if( o.sz.inside( x, y ) ) o->data[ y * o->sz.width + x ].set_u2( v ); };
    func (u3_t pix_u2_from_idx( @* o, v2i_s* idx )) = { return o.get_pix_u2( idx.x, idx.y ); };

    func (void set_pix_rgba( m@* o, sz_t x, sz_t y, u0_t r, u0_t g, u0_t b, u0_t a )) =
    {
        if( o.sz.inside( x, y ) )
        {
            m rgba_s* rgba = o->data[ y * o->sz.width + x ];
            rgba.r = r;
            rgba.g = g;
            rgba.b = b;
            rgba.a = a;
        }
    };
};

//----------------------------------------------------------------------------------------------------------------------

stamp u3_buf_s = x_array { u3_t []; };

func (rgba_image_s) (void fill_cub_from_depth_image( m@* o, c depth_image_s* depth_image, c color_map_s* color_map, psp_s psp )) =
{
    u3_buf_s^ buf.set_size( o.sz.width );
    for( sz_t y = 0; y < o->sz.height; y++ )
    {
        depth_image.fill_cub_row_from_pos( psp.map( :pos_from_idx_xy( o->sz, 0, y ) ), psp.s, buf.data, o.sz.width );
        for( sz_t x = 0; x < o->sz.width; x++ )
        {
            color_s c = color_map.map( buf.[ x ] );
            o.set_pix_rgba( x, y, c.r_to_u0(), c.g_to_u0(), c.b_to_u0(), 0 );
        }
    }
};

//----------------------------------------------------------------------------------------------------------------------

/**********************************************************************************************************************/

