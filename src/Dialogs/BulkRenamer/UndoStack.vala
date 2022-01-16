    public class Stack<G> {
        private Gee.LinkedList<G> list;

        public Stack () {
            list = new Gee.LinkedList<G> ();
        }

        public Stack<G> push (G element) {
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

        public Gee.List<G>? slice_head (int amount) {
            return list.slice (0, int.min (size (), amount));
        }
    }
