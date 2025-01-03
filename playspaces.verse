playspaces<public> := module:
    using { core.containers }
    using { core.players }
    using { /Fortnite.com/Playspaces }
    using { /Verse.org/Concurrency }
    using { /Verse.org/Simulation }

    ConstructPlayerOnboardingRoutine<public><constructor>(Playspace: fort_playspace) := player_onboarding:
        Playspace := Playspace

    player_onboarding<public> := class<internal><final>:
        Playspace: fort_playspace

        LookupCapacity<private>: int = 256
        PlayerOnboardedEvent<private>: event(player_onboarding_result) = event(player_onboarding_result){}

        var PlayerRemovedSignalableLookup<private>: [player]signalable(tuple()) = map{}

        StartOnboardingPlayers<public>(): void =
            spawn:
                AwaitAddedPlayers()
            spawn:
                AwaitRemovedPlayers()
            OnboardPlayersOnStart()

        AwaitPlayerOnboarded<public>()<suspends>: player_onboarding_result = PlayerOnboardedEvent.Await()

        AwaitAddedPlayers<private>()<suspends>: void =
            PlayerAddedEvent := Playspace.PlayerAddedEvent()
            loop:
                AddedPlayer := PlayerAddedEvent.Await()
                AddedPlayer.StartOnboarding()

        AwaitRemovedPlayers<private>()<suspends>: void =
            PlayerRemovedEvent := Playspace.PlayerRemovedEvent()
            loop:
                RemovedPlayer := PlayerRemovedEvent.Await()
                if (PlayerRemovedSignalable := PlayerRemovedSignalableLookup[RemovedPlayer]):
                    PlayerRemovedSignalable.Signal()
        
        OnboardPlayersOnStart<private>(): void =
            Players := Playspace.GetPlayers()
            for (Player : Players):
                Player.StartOnboarding()

        (OnboardingPlayer: player).StartOnboarding<private>(): void =
            PlayerLeaveEvent := event(void){}
            if (OnboardingPlayer.PutOnLookup[PlayerLeaveEvent]):
                spawn{OnboardingPlayer.HandleOnboarding(PlayerLeaveEvent)}

        (OnboardingPlayer: player).HandleOnboarding<private>(PlayerRemovedAwaitable: awaitable(void))<suspends>: void = race:
            OnboardingPlayer.SignalWhenActive(PlayerRemovedAwaitable)
            PlayerRemovedAwaitable.Await()

        (OnboardingPlayer: player).SignalWhenActive<private>(PlayerRemovedAwaitable: awaitable(void))<suspends>: void =
            loop:
                if (OnboardingPlayer.IsActive[]):
                    break
                Sleep(0.0)
            OnboardingResult := player_onboarding_result:
                Player := OnboardingPlayer
                PlayerRemovedEvent := PlayerRemovedAwaitable
            PlayerOnboardedEvent.Signal(OnboardingResult)

        (OnboardingPlayer: player).PutOnLookup<private>(PlayerLeaveSignalable: signalable(void))<transacts><decides>: void =
            set PlayerRemovedSignalableLookup[OnboardingPlayer] = PlayerLeaveSignalable
            if (PlayerRemovedSignalableLookup.Length > LookupCapacity):
                set PlayerRemovedSignalableLookup = PlayerRemovedSignalableLookup.FilterByKey(PlayerIsActive)

    player_onboarding_result<public> := struct:
        Player: player
        PlayerRemovedEvent: awaitable()
