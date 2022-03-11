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
    func o set_sz( m@* o, sz2i_s sz ) { o.set_size( sz.width * sz.height ); o.sz = sz; = o; }
    func u3_t get_pix( @* o, sz_t x, sz_t y ) = o.sz.inside( x, y ) ? o.[ y * o.sz.width + x ] : 0;
    func void set_pix( m@* o, sz_t x, sz_t y, u3_t v ) if( o.sz.inside( x, y ) ) o.[ y * o.sz.width + x ] = v;
    func u3_t get_max( const depth_image_s* o ) { u3_t r =  0; foreach( u3_t v in o ) r = v > r ? v : r; = r; }
    func u3_t get_min( const depth_image_s* o ) { u3_t r = -1; foreach( u3_t v in o ) r = v < r ? v : r; = r; }
    func u3_t pix_from_idx( @* o, v2i_s* idx ) = o.get_pix( idx.x, idx.y );

    func u3_range_s get_range( const depth_image_s* o )
    {
        u3_range_s r; r.max = 0; r.min = -1;
        foreach( u3_t v in o )
        {
            r.min = v < r.min ? v : r.min;
            r.max = v > r.max ? v : r.max;
        }
        = r;
    }
};

//----------------------------------------------------------------------------------------------------------------------

func (depth_image_s) u3_t cub_pix_from_pos( @* o, v2f_s pos )
{
    v2f_s fdx = :fdx_from_pos( o.sz, pos );
    v2i_s idx = { f3_rs3( fdx.x - 0.5 ), f3_rs3( fdx.y - 0.5 ) };
    s3_t x = f3_rs3( ( fdx.x - idx.x ) * 64 );
    s3_t y = f3_rs3( ( fdx.y - idx.y ) * 64 );

    s3_t a; s3_t b; s3_t c; s3_t d; s3_t r; s3_t s; s3_t t; s3_t u;
    s3_t v; s3_t va; s3_t vb; s3_t vc; s3_t vd;

    a = o.get_pix( idx.x - 1, idx.y - 1 );
    b = o.get_pix( idx.x    , idx.y - 1 );
    c = o.get_pix( idx.x + 1, idx.y - 1 );
    d = o.get_pix( idx.x + 2, idx.y - 1 );

    t = c - a;
    u = 2 * b;
    r =     d + 3 * b - a - 3 * c;
    s = 2 * a - 5 * b - d + 4 * c;

    v  = ( r * x * x * x );
    v += ( s * x * x     ) << 6;
    v += ( t * x         ) << 12;
    v += ( u             ) << 18;

    va = ( v + ( 1 << 18 ) ) >> 19;

    a = o.get_pix( idx.x - 1, idx.y );
    b = o.get_pix( idx.x    , idx.y );
    c = o.get_pix( idx.x + 1, idx.y );
    d = o.get_pix( idx.x + 2, idx.y );

    t = c - a;
    u = 2 * b;
    r =     d + 3 * b - a - 3 * c;
    s = 2 * a - 5 * b - d + 4 * c;

    v  = ( r * x * x * x );
    v += ( s * x * x     ) << 6;
    v += ( t * x         ) << 12;
    v += ( u             ) << 18;

    vb = ( v + ( 1 << 18 ) ) >> 19;

    a = o.get_pix( idx.x - 1, idx.y + 1 );
    b = o.get_pix( idx.x    , idx.y + 1 );
    c = o.get_pix( idx.x + 1, idx.y + 1 );
    d = o.get_pix( idx.x + 2, idx.y + 1 );

    t = c - a;
    u = 2 * b;
    r =     d + 3 * b - a - 3 * c;
    s = 2 * a - 5 * b - d + 4 * c;

    v  = ( r * x * x * x );
    v += ( s * x * x     ) << 6;
    v += ( t * x         ) << 12;
    v += ( u             ) << 18;

    vc = ( v + ( 1 << 18 ) ) >> 19;

    a = o.get_pix( idx.x - 1, idx.y + 2 );
    b = o.get_pix( idx.x    , idx.y + 2 );
    c = o.get_pix( idx.x + 1, idx.y + 2 );
    d = o.get_pix( idx.x + 2, idx.y + 2 );

    t = c - a;
    u = 2 * b;
    r =     d + 3 * b - a - 3 * c;
    s = 2 * a - 5 * b - d + 4 * c;

    v  = ( r * x * x * x );
    v += ( s * x * x     ) << 6;
    v += ( t * x         ) << 12;
    v += ( u             ) << 18;

    vd = ( v + ( 1 << 18 ) ) >> 19;

    t = vc - va;
    u = 2 * vb;
    r =     vd + 3 * vb - va - 3 * vc;
    s = 2 * va - 5 * vb - vd + 4 * vc;

    v  = ( r * y * y * y );
    v += ( s * y * y     ) << 6;
    v += ( t * y         ) << 12;
    v += ( u             ) << 18;

    v = ( v + ( 1 << 18 ) ) >> 19;

    = v < 0 ? 0 : v;
}

//----------------------------------------------------------------------------------------------------------------------

stamp :hist_s = x_array { f3_t []; };
func (depth_image_s) void equalize_histogram( @* o )
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
            f3_t w = f3_exp( - ( x * x + y * y ) * 4 );
            if( v > 0 ) hist.[ ( v - range.min ) >> shr ] += w;
        }
    }

    f3_t hsum = 0;
    foreach( m f3_t* v in hist ) *v = ( hsum += *v );

    u3_t max_out = 65536;

    f3_t f = max_out.cast( f3_t ) / ( ( hsum > 0 ) ? hsum : 1 );

    foreach( m u3_t* v in o ) *v = hist.[ ( *v - range.min ) >> shr ] * f;
}

//----------------------------------------------------------------------------------------------------------------------

/**********************************************************************************************************************/
/// color

//----------------------------------------------------------------------------------------------------------------------

func u0_t v_to_u0( f3_t v ) = ( v <= 0 ) ? 0.0 : ( v >= 1.0 ) ? 255 : v * 255;

stamp color_s = obliv x_inst
{
    f3_t r; f3_t g; f3_t b;

    func u0_t r_to_u0( @* o ) = :v_to_u0( o.r );
    func u0_t g_to_u0( @* o ) = :v_to_u0( o.g );
    func u0_t b_to_u0( @* o ) = :v_to_u0( o.b );
};

//----------------------------------------------------------------------------------------------------------------------

stamp color_map_s =
{
//    f3_t ra = 1.0; f3_t rb = 2.0; f3_t rc = 4.0;
//    f3_t ga = 2.0; f3_t gb = 1.0; f3_t gc = 3.0;
//    f3_t ba = 5.0; f3_t bb = 3.0; f3_t bc = 1.0;

    f3_t ra = 1.0; f3_t rb = 2.5; f3_t rc = 4.0;
    f3_t ga = 3.0; f3_t gb = 1.0; f3_t gc = 3.0;
    f3_t ba = 5.0; f3_t bb = 4.0; f3_t bc = 1.0;

//    f3_t ra = 5.0; f3_t rb = 4.0; f3_t rc = 1.0;
//    f3_t ga = 5.0; f3_t gb = 1.0; f3_t gc = 5.0;
//    f3_t ba = 1.0; f3_t bb = 2.5; f3_t bc = 4.0;

    func color_s map( @* o, u3_t val )
    {
        color_s c;
        f3_t v = ( f3_t )( val ) / 65536;
        c.r = f3_sin( f3_pow( v, o.ra ) * o.rb * f3_pi() ) * ( 1 - v ) + f3_pow( v, o.rc ) * v;
        c.g = f3_sin( f3_pow( v, o.ga ) * o.gb * f3_pi() ) * ( 1 - v ) + f3_pow( v, o.gc ) * v;
        c.b = f3_sin( f3_pow( v, o.ba ) * o.bb * f3_pi() ) * ( 1 - v ) + f3_pow( v, o.bc ) * v;
        = c;
    }
}

//----------------------------------------------------------------------------------------------------------------------

/**********************************************************************************************************************/
/// rgba_image

//----------------------------------------------------------------------------------------------------------------------

stamp rgba_s = obliv x_inst
{
    u0_t b; u0_t g; u0_t r; u0_t a;
    func u2_t u2( @*o ) = o.cast( u2_t* ).0;
    func void set_u2( m@*o, u2_t v ) o.cast( m u2_t* ).0 = v;
}

//----------------------------------------------------------------------------------------------------------------------

stamp rgba_image_s = x_array
{
    rgba_s [];
    sz2i_s sz;

    func o set_sz( m@* o, sz2i_s sz ) { o.set_size( sz.width * sz.height ); o.sz = sz; }
    func u2_t get_pix_u2( @* o, sz_t x, sz_t y ) = o.sz.inside( x, y ) ? o.[ y * o.sz.width + x ].u2() : 0;
    func rgba_s* get_pix( @* o, sz_t x, sz_t y ) = o.sz.inside( x, y ) ? o.[ y * o.sz.width + x ].1 : NULL;
    func void set_pix_u2( m@* o, sz_t x, sz_t y, u2_t v ) if( o.sz.inside( x, y ) ) o.[ y * o.sz.width + x ].set_u2( v );
    func u3_t pix_u2_from_idx( @* o, v2i_s* idx ) = o.get_pix_u2( idx.x, idx.y );

    func void set_pix_rgba( m@* o, sz_t x, sz_t y, u0_t r, u0_t g, u0_t b, u0_t a )
    {
        if( o.sz.inside( x, y ) )
        {
            m rgba_s* rgba = o.[ y * o.sz.width + x ];
            rgba.r = r;
            rgba.g = g;
            rgba.b = b;
            rgba.a = a;
        }
    }
}

//----------------------------------------------------------------------------------------------------------------------

func (rgba_image_s) void fill_cub_from_depth_image( m @* o, depth_image_s* depth_image, color_map_s* color_map, psp_s psp )
{
    for( sz_t y = 0; y < o.sz.height; y++ )
    {
        for( sz_t x = 0; x < o.sz.width; x++ )
        {
            v2f_s pos = :pos_from_idx( o.sz, v2i_s_of( x, y ) );
            color_s c = color_map.map( depth_image.cub_pix_from_pos( psp.map( pos ) ) );
            o.set_pix_rgba( x, y, c.r_to_u0(), c.g_to_u0(), c.b_to_u0(), 0 );
        }
    }
}

//----------------------------------------------------------------------------------------------------------------------

/**********************************************************************************************************************/

