/***
    Copyright (c) 2010 ammonkey

    This library is free software; you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License
    version 3.0 as published by the Free Software Foundation.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License version 3.0 for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library. If not, see
    <http://www.gnu.org/licenses/>.

    Author: ammonkey <am.monkeyd@gmail.com>
***/

//Acts like a LAST-IN-FIRST-OUT queue but allows peeking a number of items from the head
public class BrowserStack<G> {
    private Gee.LinkedList<G> list;

    public BrowserStack () {
        list = new Gee.LinkedList<G> ();
    }

    public BrowserStack<G> push (G element) {
        list.offer_head (element);
        return this;
    }

    public G pop () {
        return list.poll_head ();
    }

    public G peek () {
        return list.peek_head ();
    }

    public int size () {
        return list.size;
    }

    public void clear () {
        list.clear ();
    }

    public bool is_empty () {
        return size () == 0;
    }

    // Peeks the top @amount items in the list (but does not remove them)
    public Gee.List<G>? slice_head (int amount) {
        return list.slice (0, int.min (size (), amount));
    }
}
