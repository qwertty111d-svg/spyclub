-- Create NEW Developer Products in this experience, then enter their real IDs.
-- Existing paid IDs retain their historical rewards and must never be reused.
return {
    BasePrice=99,
    MaxPackRolls=5,
    Packs={
        {key="rolls_1",id=0,rolls=1,previewPrice=99},
        {key="rolls_3",id=0,rolls=3,previewPrice=279},
        {key="rolls_5",id=0,rolls=5,previewPrice=449},
    },
}
