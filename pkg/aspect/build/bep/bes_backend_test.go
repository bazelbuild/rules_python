/*
Copyright © 2021 Aspect Build Systems Inc

Not licensed for re-use.
*/

package bep

import (
	"context"
	"fmt"
	"io"
	"net"
	"testing"

	"github.com/golang/mock/gomock"
	. "github.com/onsi/gomega"
	buildv1 "google.golang.org/genproto/googleapis/devtools/build/v1"
	"google.golang.org/protobuf/types/known/anypb"

	buildeventstream "aspect.build/cli/bazel/buildeventstream/proto"
	"aspect.build/cli/pkg/aspecterrors"
	grpc_mock "aspect.build/cli/pkg/aspectgrpc/mock"
	stdlib_mock "aspect.build/cli/pkg/stdlib/mock"
)

func TestSetup(t *testing.T) {
	t.Run("fails when netListen fails", func(t *testing.T) {
		g := NewGomegaWithT(t)

		listenErr := fmt.Errorf("failed listen")
		besBackend := &besBackend{
			netListen: func(network, address string) (net.Listener, error) {
				return nil, listenErr
			},
		}
		err := besBackend.Setup()

		g.Expect(err).To(MatchError(fmt.Errorf("failed to setup BES backend: %w", listenErr)))
	})

	t.Run("succeeds when netListen succeeds", func(t *testing.T) {
		g := NewGomegaWithT(t)

		besBackend := &besBackend{
			netListen: func(network, address string) (net.Listener, error) {
				return nil, nil // It's fine to return nil for net.Listener as it doesn't get called in Setup.
			},
		}
		err := besBackend.Setup()

		g.Expect(err).To(BeNil())
	})
}

func TestServeWait(t *testing.T) {
	t.Run("fails when grpcServer.Serve fails", func(t *testing.T) {
		g := NewGomegaWithT(t)
		ctrl := gomock.NewController(t)
		defer ctrl.Finish()

		grpcServer := grpc_mock.NewMockServer(ctrl)
		serveErr := fmt.Errorf("failed serve")
		grpcServer.
			EXPECT().
			Serve(gomock.Any()).
			Return(serveErr).
			Times(1)
		addr := stdlib_mock.NewMockNetAddr(ctrl)
		addr.
			EXPECT().
			String().
			Return("127.0.0.1:12345").
			Times(1)
		listener := stdlib_mock.NewMockNetListener(ctrl)
		listener.
			EXPECT().
			Addr().
			Return(addr).
			Times(1)
		grpcDialer := grpc_mock.NewMockDialer(ctrl)
		grpcDialer.
			EXPECT().
			DialContext(gomock.Any(), "127.0.0.1:12345", gomock.Any(), gomock.Any()).
			Return(nil, fmt.Errorf("dial error")).
			AnyTimes()

		besBackend := &besBackend{
			grpcServer: grpcServer,
			listener:   listener,
			grpcDialer: grpcDialer,
		}
		err := besBackend.ServeWait(context.Background())

		g.Expect(err).To(MatchError(fmt.Errorf("failed to serve and wait BES backend: %w", serveErr)))
	})

	t.Run("fails when grpcDialer.DialContext exceeds timeout", func(t *testing.T) {
		g := NewGomegaWithT(t)
		ctrl := gomock.NewController(t)
		defer ctrl.Finish()

		grpcServer := grpc_mock.NewMockServer(ctrl)
		grpcServer.
			EXPECT().
			Serve(gomock.Any()).
			Return(nil).
			AnyTimes()
		addr := stdlib_mock.NewMockNetAddr(ctrl)
		addr.
			EXPECT().
			String().
			Return("127.0.0.1:12345").
			Times(1)
		listener := stdlib_mock.NewMockNetListener(ctrl)
		listener.
			EXPECT().
			Addr().
			Return(addr).
			Times(1)
		grpcDialer := grpc_mock.NewMockDialer(ctrl)
		grpcDialer.
			EXPECT().
			DialContext(gomock.Any(), "127.0.0.1:12345", gomock.Any(), gomock.Any()).
			Return(nil, context.DeadlineExceeded).
			Times(1)

		besBackend := &besBackend{
			grpcServer: grpcServer,
			listener:   listener,
			grpcDialer: grpcDialer,
		}
		err := besBackend.ServeWait(context.Background())

		g.Expect(err).To(MatchError(fmt.Errorf("failed to serve and wait BES backend: %w", context.DeadlineExceeded)))
	})

	t.Run("succeeds when grpcDialer.DialContext connects", func(t *testing.T) {
		g := NewGomegaWithT(t)
		ctrl := gomock.NewController(t)
		defer ctrl.Finish()

		grpcServer := grpc_mock.NewMockServer(ctrl)
		grpcServer.
			EXPECT().
			Serve(gomock.Any()).
			Return(nil).
			AnyTimes()
		addr := stdlib_mock.NewMockNetAddr(ctrl)
		addr.
			EXPECT().
			String().
			Return("127.0.0.1:12345").
			Times(1)
		listener := stdlib_mock.NewMockNetListener(ctrl)
		listener.
			EXPECT().
			Addr().
			Return(addr).
			Times(1)
		clientConn := grpc_mock.NewMockClientConn(ctrl)
		clientConn.
			EXPECT().
			Close().
			Return(nil).
			Times(1)
		grpcDialer := grpc_mock.NewMockDialer(ctrl)
		grpcDialer.
			EXPECT().
			DialContext(gomock.Any(), "127.0.0.1:12345", gomock.Any(), gomock.Any()).
			Return(clientConn, nil).
			Times(1)

		besBackend := &besBackend{
			grpcServer: grpcServer,
			listener:   listener,
			grpcDialer: grpcDialer,
		}
		err := besBackend.ServeWait(context.Background())

		g.Expect(err).To(BeNil())
	})
}

func TestGracefulStop(t *testing.T) {
	t.Run("calls grpcServer.GracefulStop and closes the listener", func(t *testing.T) {
		ctrl := gomock.NewController(t)
		defer ctrl.Finish()

		grpcServer := grpc_mock.NewMockServer(ctrl)
		grpcServer.
			EXPECT().
			GracefulStop().
			Times(1)
		listener := stdlib_mock.NewMockNetListener(ctrl)
		listener.
			EXPECT().
			Close().
			Return(nil).
			Times(1)

		besBackend := &besBackend{
			grpcServer: grpcServer,
			listener:   listener,
		}
		besBackend.GracefulStop()
	})
}

func TestPublishBuildToolEventStream(t *testing.T) {
	t.Run("fails when stream.Recv fails", func(t *testing.T) {
		g := NewGomegaWithT(t)
		ctrl := gomock.NewController(t)
		defer ctrl.Finish()

		eventStream := grpc_mock.NewMockPublishBuildEvent_PublishBuildToolEventStreamServer(ctrl)
		expectedErr := fmt.Errorf("failed to receive")
		eventStream.
			EXPECT().
			Recv().
			Return(nil, expectedErr).
			Times(1)

		besBackend := &besBackend{}
		err := besBackend.PublishBuildToolEventStream(eventStream)

		g.Expect(err).To(MatchError(expectedErr))
	})

	t.Run("fails when stream.Send fails", func(t *testing.T) {
		g := NewGomegaWithT(t)
		ctrl := gomock.NewController(t)
		defer ctrl.Finish()

		eventStream := grpc_mock.NewMockPublishBuildEvent_PublishBuildToolEventStreamServer(ctrl)
		event := &buildv1.BuildEvent{}
		streamId := &buildv1.StreamId{BuildId: "1"}
		orderedBuildEvent := &buildv1.OrderedBuildEvent{
			StreamId:       streamId,
			SequenceNumber: 1,
			Event:          event,
		}
		req := &buildv1.PublishBuildToolEventStreamRequest{OrderedBuildEvent: orderedBuildEvent}
		recv := eventStream.
			EXPECT().
			Recv().
			Return(req, nil).
			Times(1)
		res := &buildv1.PublishBuildToolEventStreamResponse{
			StreamId:       req.OrderedBuildEvent.StreamId,
			SequenceNumber: req.OrderedBuildEvent.SequenceNumber,
		}
		expectedErr := fmt.Errorf("failed to send")
		eventStream.
			EXPECT().
			Send(res).
			Return(expectedErr).
			Times(1).
			After(recv)

		besBackend := &besBackend{subscribers: &subscriberList{}}
		err := besBackend.PublishBuildToolEventStream(eventStream)

		g.Expect(err).To(MatchError(expectedErr))
	})

	t.Run("succeeds without subscribers", func(t *testing.T) {
		g := NewGomegaWithT(t)
		ctrl := gomock.NewController(t)
		defer ctrl.Finish()

		eventStream := grpc_mock.NewMockPublishBuildEvent_PublishBuildToolEventStreamServer(ctrl)
		event := &buildv1.BuildEvent{}
		streamId := &buildv1.StreamId{BuildId: "1"}
		orderedBuildEvent := &buildv1.OrderedBuildEvent{
			StreamId:       streamId,
			SequenceNumber: 1,
			Event:          event,
		}
		req := &buildv1.PublishBuildToolEventStreamRequest{OrderedBuildEvent: orderedBuildEvent}
		recv := eventStream.
			EXPECT().
			Recv().
			Return(req, nil).
			Times(1)
		res := &buildv1.PublishBuildToolEventStreamResponse{
			StreamId:       req.OrderedBuildEvent.StreamId,
			SequenceNumber: req.OrderedBuildEvent.SequenceNumber,
		}
		send := eventStream.
			EXPECT().
			Send(res).
			Return(nil).
			Times(1).
			After(recv)
		eventStream.
			EXPECT().
			Recv().
			Return(nil, io.EOF).
			Times(1).
			After(send)

		besBackend := &besBackend{subscribers: &subscriberList{}}
		err := besBackend.PublishBuildToolEventStream(eventStream)

		g.Expect(err).To(Not(HaveOccurred()))
	})

	t.Run("succeeds with subscribers", func(t *testing.T) {
		g := NewGomegaWithT(t)
		ctrl := gomock.NewController(t)
		defer ctrl.Finish()

		eventStream := grpc_mock.NewMockPublishBuildEvent_PublishBuildToolEventStreamServer(ctrl)
		buildEvent := &buildeventstream.BuildEvent{}
		var anyBuildEvent anypb.Any
		anyBuildEvent.MarshalFrom(buildEvent)
		event := &buildv1.BuildEvent{Event: &buildv1.BuildEvent_BazelEvent{BazelEvent: &anyBuildEvent}}
		streamId := &buildv1.StreamId{BuildId: "1"}
		orderedBuildEvent := &buildv1.OrderedBuildEvent{
			StreamId:       streamId,
			SequenceNumber: 1,
			Event:          event,
		}
		req := &buildv1.PublishBuildToolEventStreamRequest{OrderedBuildEvent: orderedBuildEvent}
		recv := eventStream.
			EXPECT().
			Recv().
			Return(req, nil).
			Times(1)
		res := &buildv1.PublishBuildToolEventStreamResponse{
			StreamId:       req.OrderedBuildEvent.StreamId,
			SequenceNumber: req.OrderedBuildEvent.SequenceNumber,
		}
		send := eventStream.
			EXPECT().
			Send(res).
			Return(nil).
			Times(1).
			After(recv)
		eventStream.
			EXPECT().
			Recv().
			Return(nil, io.EOF).
			Times(1).
			After(send)

		besBackend := &besBackend{
			subscribers: &subscriberList{},
			errors:      &aspecterrors.ErrorList{},
		}
		var calledSubscriber1, calledSubscriber2, calledSubscriber3 bool
		besBackend.RegisterSubscriber(func(evt *buildeventstream.BuildEvent) error {
			g.Expect(evt).To(Equal(buildEvent))
			calledSubscriber1 = true
			return nil
		})
		expectedSubscriber2Err := fmt.Errorf("error from subscriber 2")
		besBackend.RegisterSubscriber(func(evt *buildeventstream.BuildEvent) error {
			g.Expect(evt).To(Equal(buildEvent))
			calledSubscriber2 = true
			return expectedSubscriber2Err
		})
		expectedSubscriber3Err := fmt.Errorf("error from subscriber 3")
		besBackend.RegisterSubscriber(func(evt *buildeventstream.BuildEvent) error {
			g.Expect(evt).To(Equal(buildEvent))
			calledSubscriber3 = true
			return expectedSubscriber3Err
		})
		err := besBackend.PublishBuildToolEventStream(eventStream)

		g.Expect(err).To(Not(HaveOccurred()))
		g.Expect(calledSubscriber1).To(BeTrue())
		g.Expect(calledSubscriber2).To(BeTrue())
		g.Expect(calledSubscriber3).To(BeTrue())

		subscriberErrs := besBackend.Errors()
		g.Expect(subscriberErrs[0]).To(MatchError(expectedSubscriber2Err))
		g.Expect(subscriberErrs[1]).To(MatchError(expectedSubscriber3Err))
	})
}
