namespace Marlin.Animation{
    static void smooth_adjustment_upper(Gtk.Adjustment adj) {
        Timeout.add(1000/60, () => {
            if(adj.value >= adj.upper - adj.page_size)
            {
                return false;
            }
            adj.value = adj.value + 10;
            return true;

        });
    }
}

