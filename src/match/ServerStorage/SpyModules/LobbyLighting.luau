local Lighting={}
function Lighting.apply()
    local l=game:GetService("Lighting")
    l.ClockTime,l.Brightness,l.GlobalShadows=0,1.6,true
    l.Ambient,l.OutdoorAmbient=Color3.fromRGB(74,69,85),Color3.fromRGB(45,47,64)
    l.EnvironmentDiffuseScale,l.EnvironmentSpecularScale=.6,.7
    local bloom=l:FindFirstChild("ClubBloom") or Instance.new("BloomEffect")
    bloom.Name,bloom.Intensity,bloom.Size,bloom.Threshold="ClubBloom",.13,18,1.5;bloom.Parent=l
    local grade=l:FindFirstChild("ClubGrade") or Instance.new("ColorCorrectionEffect")
    grade.Name,grade.Brightness,grade.Contrast,grade.Saturation="ClubGrade",.02,.08,-.08
    grade.TintColor,grade.Parent=Color3.fromRGB(255,243,234),l
end
return Lighting
