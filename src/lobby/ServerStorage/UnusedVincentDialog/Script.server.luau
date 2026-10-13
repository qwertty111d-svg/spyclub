script.Parent.DialogChoiceSelected:connect(function(player, choice)
if choice == script.Parent.C then
gunB = game.Lighting["Wine!"]:clone()
gunB.Parent = player.Backpack
elseif choice == script.Parent.D then
gunC = game.Lighting["Weezy"]:clone()
gunC.Parent = player.Backpack
elseif choice == script.Parent.E then
gunC = game.Lighting["Miller"]:clone()
gunC.Parent = player.Backpack
end
end)