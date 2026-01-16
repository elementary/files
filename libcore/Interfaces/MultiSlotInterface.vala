/* You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA
 *
 * Authored by: Jeremy Wootten <jeremywootten@gmail.com>
 */

/* Interface for classes displaying several slots in a single view. Classes using this interface: Miller.vala
 */

    public interface MultiSlotInterface : Gtk.Widget {
        // Special handling for certain keys
        public abstract bool on_miller_key_pressed (uint original_keyval, uint keycode, Gdk.ModifierType state);
    }
