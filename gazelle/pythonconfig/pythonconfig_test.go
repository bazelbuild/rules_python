package pythonconfig

import (
	"reflect"
	"testing"
)

func TestConfigNewChild(t *testing.T) {
	parent := New("foo", "bar")
	child := parent.NewChild()

	if child.parent == nil {
		t.Error("child parent should not be nil")
	}
	child.parent = nil
	if !reflect.DeepEqual(child, parent) {
		t.Errorf("child and should should be equal other than the parent reference. Parent: %#v\nChild: %#v", parent, child)
	}
}
