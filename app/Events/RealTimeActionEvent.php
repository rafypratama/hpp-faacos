<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class RealTimeActionEvent implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public $userName;
    public $userRole;
    public $action;
    public $description;
    public $timestamp;

    /**
     * Create a new event instance.
     */
    public function __construct(string $userName, string $userRole, string $action, string $description)
    {
        $this->userName = $userName;
        $this->userRole = $userRole;
        $this->action = $action;
        $this->description = $description;
        $this->timestamp = now()->toIso8601String();
    }

    /**
     * Get the channels the event should broadcast on.
     *
     * @return array<int, \Illuminate\Broadcasting\Channel>
     */
    public function broadcastOn(): array
    {
        return [
            new Channel('faacos-events'),
        ];
    }

    /**
     * Name of the broadcast event.
     */
    public function broadcastAs(): string
    {
        return 'realtime-action';
    }
}
