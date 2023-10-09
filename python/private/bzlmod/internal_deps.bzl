#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"Python toolchain module extension for internal rule use"

load("//python/pip_install:repositories.bzl", "pip_install_dependencies")
load("//python/private:internal_config_repo.bzl", "internal_config_repo")

# buildifier: disable=unused-variable
def _internal_deps_impl(module_ctx):
    internal_config_repo(name = "rules_python_internal")
    pip_install_dependencies()

internal_deps = module_extension(
    doc = "This extension to register internal rules_python dependecies.",
    implementation = _internal_deps_impl,
    tag_classes = {
        "install": tag_class(attrs = dict()),
    },
)
