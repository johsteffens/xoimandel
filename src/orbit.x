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

//----------------------------------------------------------------------------------------------------------------------

/// complex number
stamp cx_s = obliv
{
    f3_t r; f3_t i;
    func (@    of( f3_t r, f3_t i )) = { cx_s c; c.r = r; c.i = i; return c; };
    func (@    add( @ o, @ b )) = { return cx_s_of( o.r + b.r, o.i + b.i ); };
    func (@    sub( @ o, @ b )) = { return cx_s_of( o.r - b.r, o.i - b.i ); };
    func (@    mul( @ o, @ b )) = { return cx_s_of( o.r * b.r - o.i * b.i, o.r * b.i + o.i * b.r ); };
    func (@    sqr( @ o ))      = { return cx_s_of( o.r * o.r - o.i * o.i, 2 * o.r * o.i ); };
    func (f3_t sqr_mag( @ o ))  = { return o.r * o.r + o.i * o.i; };
};

//----------------------------------------------------------------------------------------------------------------------

stamp orbit_s =
{
    u3_t max_iterations = 16000;
};

//----------------------------------------------------------------------------------------------------------------------

func (orbit_s) (u3_t escape_time( @* o, v2f_s pos )) =
{
    cx_s c = { pos.x, pos.y };
    cx_s v = c;

    // cardioid - test
    f3_t a = v.r - 0.25;
    f3_t b = v.i * v.i;
    f3_t q = a * a + b;
    if( q * ( q + a ) < 0.25 * b ) return 0;

    // bulb - test
    if( :f3_sqr( v.r + 1 ) + :f3_sqr( v.i ) < 0.0625 ) return 0;


    f3_t limit = 1 << 16;
    u3_t i = 1;

//    for( ; i <= o->max_iterations && v.sqr_mag() < limit; i++ )
//    {
//        v = v.sqr().add( c );
//    }

    // We do multiple complex iterations at once for better efficiency.
    // The escape criterion need not be tested each iteration.
    for( ; i <= o->max_iterations && v.sqr_mag() < limit; i += 2 )
    {
        v = v.sqr().add( c ).sqr().add( c );
    }


    f3_t sqr_mag = v.sqr_mag();

    if( sqr_mag <= 4.0 ) return 0;

    f3_t offs = 1.0 - :f3_log( :f3_log( sqr_mag ) / :f3_log( limit ) ) / :f3_log( 2.0 );

    return ( i << 8 ) + :f3_rint( offs * 256 );
};

//----------------------------------------------------------------------------------------------------------------------

/**********************************************************************************************************************/

