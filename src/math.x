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

include "bcore_std.h";
include <gtk/gtk.h>;

//----------------------------------------------------------------------------------------------------------------------

func (f3_t f3_sqr ( f3_t o )) = { return o*o; };
func (f3_t f3_sqrt( f3_t o )) = (verbatim_C) { return sqrt(o); };
func (s3_t f3_rint( f3_t o )) = (verbatim_C) { return llrint(o); };
func (f3_t f3_sin( f3_t o )) = (verbatim_C) { return sin(o); };
func (f3_t f3_exp( f3_t v )) = (verbatim_C) { return exp( v ); };
func (f3_t f3_log( f3_t v )) = (verbatim_C) { return v > 0 ? log( v ) : -f3_lim_max; };
func (f3_t f3_pow( f3_t a, f3_t b )) = (verbatim_C) { return ( a > 0 ) ? pow( a, b ) : 0.0; };
func (f3_t f3_pi()  ) = { return 3.1415926535897932384626434; }; // PI
func (f3_t f3_pi_2()) = { return 1.5707963267948966192313217; }; // PI / 2
func (f3_t f3_tau() ) = { return 6.2831853071795864769252868; }; // 2 * PI
func (bl_t f3_is_nan( f3_t v )) = { return v != v; }; // nan compares unequal to itself

func (sz_t sz_max ( sz_t a, sz_t b )) = (verbatim_C) { return sz_max(a,b); };
func (sz_t sz_min ( sz_t a, sz_t b )) = (verbatim_C) { return sz_min(a,b); };




//----------------------------------------------------------------------------------------------------------------------

/// 2d size-vector
stamp sz2i_s = obliv x_inst
{
    sz_t width; sz_t height;
    func (@ of(sz_t w, sz_t h))   = { @ o; o.width = w; o.height = h; return o; };
    func (bl_t equal( @ o, @ b )) = { return ( o.width == b.width ) && ( o.height == b.height ); };
    func (bl_t inside( @* o, sz_t x, sz_t y )) = { return ( x >= 0 && x < o.width ) && ( y >=0 && y < o.height ); };
};

//----------------------------------------------------------------------------------------------------------------------

/// 2d vector of s3_t
stamp v2i_s = obliv x_inst
{
    s3_t x; s3_t y;
    func (@ of(s3_t x, s3_t y)) = { @ o; o.x = x; o.y = y; return o; };
};

//----------------------------------------------------------------------------------------------------------------------

/// 2d vector of f3_t
stamp v2f_s = obliv x_inst
{
    f3_t x; f3_t y;

    func (@ of(f3_t x, f3_t y))    = { @ o; o.x = x; o.y = y; return o; };
    func (@ set_zero(m@* o))       = { o.x = o.y = 0; return o; };
    func (@ neg( @ o))             = { o.x = -o.x; o.y = -o.y;  return o; };
    func (f3_t sqr( @ o ))         = { return (o.x*o.x) + (o.y*o.y); };
    func (@    add( @ o, @ a ))    = { o.x+=a.x; o.y+=a.y; return o; };
    func (@    sub( @ o, @ a ))    = { o.x-=a.x; o.y-=a.y; return o; };
    func (@    mlf( @ o, f3_t f )) = { o.x*=f; o.y*=f; return o; };
    func (f3_t mlv( @ o, @ a ))    = { return (o.x*a.x) + (o.y*a.y); };

    func (f3_t add_mlv( @ o, @ a, @ b )) = { return (o.x+a.x)*b.x + (o.y+a.y)*b.y; };
    func (f3_t sub_mlv( @ o, @ a, @ b )) = { return (o.x-a.x)*b.x + (o.y-a.y)*b.y; };

    func (@    add_mlf( @ o, @ a, f3_t f )) = { o.x=(o.x+a.x)*f; o.y=(o.y+a.y)*f; return o; };
    func (@    sub_mlf( @ o, @ a, f3_t f )) = { o.x=(o.x-a.x)*f; o.y=(o.y-a.y)*f; return o; };
    func (@    sub_mlf_add( @ o, @ a, f3_t f, @ b )) = { return o.sub_mlf( a, f ).add( b ); };

    func (f3_t diff_sqr( @ o, @ a )) = { return :f3_sqr(o.x-a.x) + :f3_sqr(o.y-a.y); };

    func (f3_t max( @ o )) = { return o.x > o.y ? o.x : o.y; };
    func (f3_t min( @ o )) = { return o.x < o.y ? o.x : o.y; };

    /// sets length of vector to abs(a) (negative a inverts vector's direction)
    func (@ of_lenth( @ o, f3_t a )) = { f3_t r = :f3_sqrt( o.sqr() ); return o.mlf( r > 0 ? ( a / r ) : 0 ); };

    /// canonic orthonormal to o
    func (@ con( @ o )) = { o = o.of_lenth( 1.0 ); f3_t x = o.x; o.x = -o.y; o.y = x; return o; };
};

//----------------------------------------------------------------------------------------------------------------------

/// psp_s linear map: point-scale-point notation
/// 2d vector of f3_t
stamp psp_s = obliv x_inst
{
    v2f_s p1; // source point
    f3_t s;   // scale
    v2f_s p2; // target point

    /// applies map to vector
    func (v2f_s map( @* o, v2f_s v )) = { return v.sub_mlf_add( o.p1, o.s, o.p2 ); };

    /// multiplies two maps (successive application)
    func (psp_s mul( @ o, @ m )) = { psp_s r; r.p1 = m.p1; r.s = m.s * o.s; r.p2 = o.map( m.p2 ); return r; };

    /// applies inverse map to vector
    func (v2f_s inv_map( @* o, v2f_s v )) = { return v.sub_mlf_add( o.p2, o.s != 0 ? 1.0 / o.s : 0, o.p1 ); };

    /// sets to identity map (p1=p2=0)
    func (o set_one(m@* o)) = { o.p1.set_zero(); o.s = 1.0; o.p2.set_zero(); return o; };

    /// sets to identity map (p1=p2=p)
    func (o set_one_at(m@* o, v2f_s p )) = { o.p1 = p; o.s = 1.0; o.p2 = p; return o; };

    /// returns '1' == identity map
    func (@ of( v2f_s p1, f3_t s, v2f_s p2 )) = { psp_s r; r.p1 = p1; r.s = s; r.p2 = p2; return r; };

    /// returns '1' == identity map
    func (@ of_one()) = { psp_s r; r.set_one(); return r; };

    /// returns inverse map
    func (@ inv( @* o )) = { psp_s r; r.p1 = o.p2; r.s = ( o.s != 0 ) ? 1.0 / o->s : 0; r.p2 = o.p1; return r; };

    /// sets p1 and p2 according to src_pos
    func (o set_pos( m@* o, v2f_s src_pos )) = { o.p2 = o.map( src_pos ); o.p1 = src_pos; return o; };
};

//----------------------------------------------------------------------------------------------------------------------

/**********************************************************************************************************************/
/// image: pixel index (idx) <-> spatial position (pos)

//----------------------------------------------------------------------------------------------------------------------

func (s3_t xi_pos_from_idx( s3_t width,  s3_t x )) = { return ( x << 1 ) + 1 - width; };
func (s3_t yi_pos_from_idx( s3_t height, s3_t y )) = { return height - ( y << 1 ) - 1; };
func (s3_t xi_idx_from_pos( s3_t width,  s3_t x )) = { return ( width  + x - 1 ) >> 1; };
func (s3_t yi_idx_from_pos( s3_t height, s3_t y )) = { return ( height - y - 1 ) >> 1; };
func (f3_t xf_pos_from_idx( s3_t width,  f3_t x )) = { return ( x * 2 ) + 1 - width; };
func (f3_t yf_pos_from_idx( s3_t height, f3_t y )) = { return height - ( y * 2 ) - 1; };
func (f3_t xf_idx_from_pos( s3_t width,  f3_t x )) = { return ( width  + x - 1 ) * 0.5; };
func (f3_t yf_idx_from_pos( s3_t height, f3_t y )) = { return ( height - y - 1 ) * 0.5; };

// returns position of indexed pixel-center
func (v2f_s pos_from_idx_xy( sz2i_s size, s3_t x, s3_t y )) =
{
    v2f_s r;
    r.x = :xi_pos_from_idx( size.width,  x );
    r.y = :yi_pos_from_idx( size.height, y );
    return r;
};

func (v2f_s pos_from_idx( sz2i_s size, v2i_s idx )) = { return :pos_from_idx_xy( size, idx.x, idx.y ); };

// returns position of pixel-coordinate
func (v2f_s pos_from_fdx_xy( sz2i_s size, f3_t x, f3_t y )) =
{
    v2f_s r;
    r.x = :xf_pos_from_idx( size.width,  x );
    r.y = :yf_pos_from_idx( size.height, y );
    return r;
};

func (v2f_s pos_from_fdx( sz2i_s size, v2f_s fdx )) = { return :pos_from_fdx_xy( size, fdx.x, fdx.y ); };

// returns nearest index
func (v2i_s idx_from_pos( sz2i_s size, v2f_s pos )) =
{
    v2i_s r;
    r.x = :f3_rint( :xf_idx_from_pos( size.width,  pos.x ) );
    r.y = :f3_rint( :yf_idx_from_pos( size.height, pos.y ) );
    return r;
};

// returns floating point pre-index ( idx = llrint( fdx ) )
func (v2f_s fdx_from_pos( sz2i_s size, v2f_s pos )) =
{
    v2f_s r;
    r.x = :xf_idx_from_pos( size.width,  pos.x );
    r.y = :yf_idx_from_pos( size.height, pos.y );
    return r;
};

//----------------------------------------------------------------------------------------------------------------------

/**********************************************************************************************************************/

