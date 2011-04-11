namespace Marlin.Animation{
    static void smooth_adjustment_upper(Gtk.Adjustment adj) {
        var initial = adj.value;
        var final = adj.upper - adj.page_size;
        var to_do = final - initial;
        var newvalue = 0;
        var old_adj_value = adj.value;

        Timeout.add(1000/60, () => {
            /* If the user move it at the same time, just stop the animation */
            if(old_adj_value != adj.value)
                return false;

            if(newvalue >= to_do - 10) {
                /* to be sure that there is not a little problem */
                adj.value = final;
                return false;
            }

            newvalue += 10;

            adj.value = initial + Math.sin(((double)newvalue/(double)to_do)*Math.PI/2)*to_do;
            old_adj_value = adj.value;
            return true;
        });
    }
}

