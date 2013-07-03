namespace Marlin.Animation {

    public static void smooth_adjustment_to (Gtk.Adjustment adj, int final)
    {
        var initial = adj.value;
        var to_do = final - initial;
        int factor;
        (to_do > 0) ? factor = 1 : factor = -1;
        to_do = (double) (((int) to_do).abs () + 1);
        var newvalue = 0;
        var old_adj_value = adj.value;

        Timeout.add(1000/60, () => {
//            /* If the user move it at the same time, just stop the animation */
//            if(old_adj_value != adj.value)
//                return false;

            if(newvalue >= to_do - 10) {
                /* to be sure that there is not a little problem */
                adj.value = final;
                return false;
            }

            newvalue += 10;

            adj.value = initial + factor * Math.sin(((double)newvalue/(double)to_do)*Math.PI/2)*to_do;
            old_adj_value = adj.value;
            return true;
        });
    }

}

