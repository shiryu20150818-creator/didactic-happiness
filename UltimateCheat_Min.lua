local P=game:GetService("Players")local R=game:GetService("RunService")local W=game:GetService("Workspace")local U=game:GetService("UserInputService")local C=W.CurrentCamera local LP=P.LocalPlayer
local repo="https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local function f(p)local ok,s=pcall(game.HttpGet,game,repo..p)if not ok or type(s)~="string"then return nil end local fn=loadstring(s)if not fn then return nil end local ok2,r=pcall(fn)return ok2 and r or nil end
local L=f("Library.lua")assert(L,"Library failed")local TM=f("addons/ThemeManager.lua")local SM=f("addons/SaveManager.lua")
local S={ESP=1,Box=1,Name=1,HP=1,Dist=1,Team=1,MaxDist=1000,Aim=1,FOV=502,Smooth=1,Curve=10,Part="Head",Sticky=1,Wall=0,BodyLock=1,Noclip=1,InfJump=1,Speed=1,SpeedVal=100,JumpPower=100,UseJP=1,AntiDie=1,BTP_Run=0,BTP_Auto=0,BTP_Target="",BTP_Dist=.5,BTP_Height=10,BTP_Int=.001,BTP_CamDist=5,BTP_CamHeight=2,BTP_Smooth=.15,BTP_TPOn=1,BTP_LockOn=1,BTP_Restore=1,CH=1,CHSize=28,CHThick=3,CHGap=4,CHSpin=1,CHSpeed=2,CHFollow=0}
local E,lk,nc,ic,orig={},nil,nil,nil,true local sp={on=0,vel=nil,att=nil,conn=nil}local btp={conn=nil,savedCF=nil,savedCam=nil,savedSub=nil,lastTP=0}local ad={enabled=false,hum=nil,char=nil,conns={},hb=nil}
local function HR(c)return c and(c:FindFirstChild("HumanoidRootPart")or c:FindFirstChild("UpperTorso")or c:FindFirstChild("Torso"))end
local function H(c)return c and c:FindFirstChildOfClass("Humanoid")end
local function tm(p)
if S.Team~=1 or not p or p==LP then return false end
-- max team check: Team object, TeamColor, neutral/same color
local ok=false
pcall(function()
if LP.Team and p.Team and LP.Team==p.Team then ok=true end
if not ok and LP.TeamColor and p.TeamColor and LP.TeamColor==p.TeamColor then ok=true end
if not ok and LP.Neutral==true and p.Neutral==true then ok=true end
-- GetTeam if custom
if not ok and LP:FindFirstChild("Team")and p:FindFirstChild("Team")then
local a,b=LP.Team,p.Team
if typeof(a)=="Instance"and typeof(b)=="Instance"and a==b then ok=true end
if typeof(a)=="StringValue"and typeof(b)=="StringValue"and a.Value~=""and a.Value==b.Value then ok=true end
end
end)
return ok
end
local function hp()return(gethui and gethui())or LP:WaitForChild("PlayerGui")end
local function adRevive(h,ch)if not h or not h.Parent then return end local mx=h.MaxHealth or 100 if mx<100 then mx=100 end pcall(function()h.Health=mx h.BreakJointsOnDeath=false h:SetStateEnabled(Enum.HumanoidStateType.Dead,false)h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,false)h:SetStateEnabled(Enum.HumanoidStateType.FallingDown,false)h.PlatformStand=false h.Sit=false h:ChangeState(Enum.HumanoidStateType.GettingUp)h:ChangeState(Enum.HumanoidStateType.Running)end)if ch then local r=ch:FindFirstChild("HumanoidRootPart")if r then pcall(function()r.AssemblyLinearVelocity=Vector3.zero r.AssemblyAngularVelocity=Vector3.zero end)end end end
local function adDetach()for _,c in ipairs(ad.conns)do pcall(function()c:Disconnect()end)end ad.conns={}if ad.hb then pcall(function()ad.hb:Disconnect()end)ad.hb=nil end ad.hum=nil ad.char=nil end
local function adAttach(ch)if not ch then return end for _,c in ipairs(ad.conns)do pcall(function()c:Disconnect()end)end ad.conns={}ad.char=ch local h=ch:FindFirstChildOfClass("Humanoid")or ch:WaitForChild("Humanoid",3)if not h then return end ad.hum=h pcall(function()h.BreakJointsOnDeath=false h:SetStateEnabled(Enum.HumanoidStateType.Dead,false)end)
ad.conns={h:GetPropertyChangedSignal("Health"):Connect(function()if not ad.enabled then return end if h.Health<=0 then adRevive(h,ch)elseif h.Health<h.MaxHealth*.5 then pcall(function()h.Health=h.MaxHealth end)end end),h.Died:Connect(function()if not ad.enabled then return end task.spawn(function()task.wait(.03)adRevive(h,ch)end)end),h.StateChanged:Connect(function(_,ns)if not ad.enabled then return end if ns==Enum.HumanoidStateType.Dead or ns==Enum.HumanoidStateType.Ragdoll or ns==Enum.HumanoidStateType.FallingDown then adRevive(h,ch)end end)}
if h.Health<h.MaxHealth then pcall(function()h.Health=h.MaxHealth end)end end
local function adStart()ad.enabled=true S.AntiDie=1 adAttach(LP.Character)table.insert(ad.conns,LP.CharacterAdded:Connect(function(c)if ad.enabled then task.wait(.1)adAttach(c)end end))if ad.hb then pcall(function()ad.hb:Disconnect()end)end ad.hb=R.Heartbeat:Connect(function()if not ad.enabled then return end local h=ad.hum if not h or not h.Parent then if LP.Character then adAttach(LP.Character)end return end if h.Health<=0 then adRevive(h,ad.char)end end)end
local function adStop()ad.enabled=false S.AntiDie=0 adDetach()end
local function nc_(v)S.Noclip=v and 1 or 0 if nc then nc:Disconnect()nc=nil end if S.Noclip==1 then nc=R.Stepped:Connect(function()local c=LP.Character if c then for _,p in ipairs(c:GetDescendants())do if p:IsA("BasePart")then p.CanCollide=false end end end end)else local c=LP.Character if c then for _,p in ipairs(c:GetDescendants())do if p:IsA("BasePart")and p.Name~="HumanoidRootPart"then p.CanCollide=true end end end end end
local function ij(v)S.InfJump=v and 1 or 0 if ic then ic:Disconnect()ic=nil end if S.InfJump==1 then ic=U.JumpRequest:Connect(function()local h=H(LP.Character)if h then h:ChangeState(Enum.HumanoidStateType.Jumping)end end)end end
local function spc()if sp.conn then sp.conn:Disconnect()sp.conn=nil end if sp.vel then pcall(function()sp.vel:Destroy()end)sp.vel=nil end if sp.att then pcall(function()sp.att:Destroy()end)sp.att=nil end end
local function sps()spc()local c=LP.Character if not c then return end local h=c:FindFirstChild("HumanoidRootPart")if not h then return end pcall(function()h:SetNetworkOwner(LP)end)local a=Instance.new("Attachment",h)local v=Instance.new("LinearVelocity",h)v.Attachment0=a v.VelocityConstraintMode=Enum.VelocityConstraintMode.Plane v.PrimaryTangentAxis=Vector3.new(1,0,0)v.SecondaryTangentAxis=Vector3.new(0,0,1)v.MaxForce=1e5 v.PlaneVelocity=Vector2.zero v.RelativeTo=Enum.ActuatorRelativeTo.World sp.att,sp.vel=a,v local t=0 sp.conn=R.Heartbeat:Connect(function()if sp.on~=1 then if sp.vel then sp.vel.PlaneVelocity=Vector2.zero end return end local cc=LP.Character if not cc or cc~=c then sps()return end local hh=cc:FindFirstChildOfClass("Humanoid")local rr=cc:FindFirstChild("HumanoidRootPart")if not hh or not rr then return end local md=hh.MoveDirection if md.Magnitude>.1 then local ff=Vector3.new(md.X,0,md.Z).Unit sp.vel.PlaneVelocity=Vector2.new(ff.X*S.SpeedVal,ff.Z*S.SpeedVal)else sp.vel.PlaneVelocity=Vector2.zero end t=t+1 if t%100==0 and h.Parent then pcall(function()h:SetNetworkOwner(LP)end)end end)end
local function spa()local h=H(LP.Character)if h then h.WalkSpeed=S.SpeedVal if S.UseJP==1 then h.UseJumpPower=true h.JumpPower=S.JumpPower else h.JumpHeight=S.JumpPower end end end
local function spt(v)S.Speed=v and 1 or 0 sp.on=S.Speed if S.Speed==1 then sps()spa()else spc()spa()end end
local function ec(p)if E[p]then pcall(function()if E[p].hl then E[p].hl:Destroy()end if E[p].bb then E[p].bb:Destroy()end end)E[p]=nil end end
local function em(p)if p==LP or tm(p)then return end ec(p)local c,hr,hu=p.Character,HR(p.Character),H(p.Character)if not c or not hr or not hu or hu.Health<=0 then return end local col=Color3.fromRGB(255,70,90)local e={p=p}if S.Box==1 then local h=Instance.new("Highlight",hp())h.Adornee=c h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop h.FillColor=col h.OutlineColor=col h.FillTransparency=.65 h.OutlineTransparency=.15 e.hl=h end if S.Name==1 or S.Dist==1 or S.HP==1 then local b=Instance.new("BillboardGui",hp())b.Adornee=hr b.AlwaysOnTop=true b.Size=UDim2.fromOffset(200,20)b.StudsOffset=Vector3.new(0,3.2,0)b.MaxDistance=S.MaxDist local l=Instance.new("TextLabel",b)l.BackgroundTransparency=1 l.Size=UDim2.fromScale(1,1)l.Font=Enum.Font.GothamBold l.TextSize=13 l.TextColor3=col l.TextStrokeTransparency=.4 e.bb,e.l=b,l end E[p]=e end
local function er()for p in pairs(E)do ec(p)end if S.ESP==1 then for _,p in ipairs(P:GetPlayers())do if p~=LP then em(p)end end end end
local function tg()if S.Sticky==1 and lk then local c,h=lk.Character,H(lk.Character)if c and h and h.Health>0 and not tm(lk)then local pt=c:FindFirstChild(S.Part)or HR(c)if pt then local sp2,os=C:WorldToViewportPoint(pt.Position)if os and sp2.Z>0 then return pt,lk end end end lk=nil end local bt,bp,bs,sc=nil,nil,-math.huge,C.ViewportSize/2 for _,p in ipairs(P:GetPlayers())do if p~=LP and not tm(p)then local c,h=p.Character,H(p.Character)if c and h and h.Health>0 then local pt=c:FindFirstChild(S.Part)or HR(c)if pt then local ok=true if S.Wall==1 then local rp=RaycastParams.new()rp.FilterType=Enum.RaycastFilterType.Exclude rp.FilterDescendantsInstances={LP.Character}local r=W:Raycast(C.CFrame.Position,pt.Position-C.CFrame.Position,rp)if r and not r.Instance:IsDescendantOf(pt.Parent)then ok=false end end if ok then local sp2,os=C:WorldToViewportPoint(pt.Position)if os and sp2.Z>0 then local d=(Vector2.new(sp2.X,sp2.Y)-sc).Magnitude if d<=S.FOV then local d3=(C.CFrame.Position-pt.Position).Magnitude local s2=(S.FOV-d)*10-d3 if s2>bs then bs,bt,bp=s2,pt,p end end end end end end end end if bt then lk=bp end return bt,bp end
local function lp()if S.ESP==1 then for p,e in pairs(E)do if not p.Parent then ec(p)else local c,hr,hu=p.Character,HR(p.Character),H(p.Character)if not c or not hr or not hu or hu.Health<=0 or tm(p)then ec(p)elseif e.hl and e.hl.Adornee~=c then em(p)elseif e.l then local my=HR(LP.Character)if my then local d=math.floor((my.Position-hr.Position).Magnitude)if d<=S.MaxDist then if e.hl then e.hl.Enabled=true end e.bb.Enabled=true local t={}if S.Name==1 then table.insert(t,p.DisplayName)end if S.HP==1 then table.insert(t,string.format("[%d/%d]",math.floor(hu.Health),math.floor(hu.MaxHealth)))end if S.Dist==1 then table.insert(t,d.."m")end e.l.Text=table.concat(t,"  ")else if e.hl then e.hl.Enabled=false end e.bb.Enabled=false end end end end end for _,p in ipairs(P:GetPlayers())do if p~=LP and not E[p]and not tm(p)then em(p)end end end if S.Aim==1 then local c,h,mh=LP.Character,H(LP.Character),HR(LP.Character)if h and mh then local t=tg()if t then C.CFrame=C.CFrame:Lerp(CFrame.new(C.CFrame.Position,t.Position),1-math.pow(1-S.Smooth,S.Curve))if S.BodyLock==1 then h.AutoRotate=false local look=Vector3.new(t.Position.X,mh.Position.Y,t.Position.Z)if(look-mh.Position).Magnitude>.1 then mh.CFrame=CFrame.lookAt(mh.Position,look)end end else lk=nil if S.BodyLock==1 then h.AutoRotate=orig end end end end end
local function BTP_HRP(p)return p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")end
local function BTP_Nearest()local m=BTP_HRP(LP)if not m then return nil end local b,bd=nil,math.huge for _,p in ipairs(P:GetPlayers())do if p~=LP then local h=BTP_HRP(p)if h then local d=(m.Position-h.Position).Magnitude if d<bd then b,bd=p,d end end end end return b end
local function BTP_BackPos(h,d,ht)if not h then return nil end return h.Position-h.CFrame.LookVector*d+h.CFrame.UpVector*ht end
local function BTP_Restore()if S.BTP_Restore~=1 or not btp.savedCF then return end local m=BTP_HRP(LP)if m then pcall(function()m.CFrame=btp.savedCF m.AssemblyLinearVelocity=Vector3.zero m.AssemblyAngularVelocity=Vector3.zero end)end btp.savedCF=nil end
local function BTP_RestoreCam()if not C then return end if btp.savedCam then C.CameraType=btp.savedCam else C.CameraType=Enum.CameraType.Custom end C.CameraSubject=btp.savedSub or(LP.Character and LP.Character:FindFirstChildOfClass("Humanoid"))end
local function BTP_Tick()local t if S.BTP_Auto==1 then t=BTP_Nearest()else t=P:FindFirstChild(S.BTP_Target)end if not t then return end local th=BTP_HRP(t)if not th then return end if S.BTP_TPOn==1 then local m=BTP_HRP(LP)if m then local now=tick()if now-btp.lastTP>=S.BTP_Int then btp.lastTP=now local pos=BTP_BackPos(th,S.BTP_Dist,S.BTP_Height)if pos then pcall(function()m.CFrame=CFrame.lookAt(pos,th.Position)m.AssemblyLinearVelocity=Vector3.zero end)end end end end if S.BTP_LockOn==1 and C then if C.CameraType~=Enum.CameraType.Scriptable then C.CameraType=Enum.CameraType.Scriptable C.CameraSubject=nil end local pos=BTP_BackPos(th,S.BTP_CamDist,S.BTP_CamHeight)if pos then local target=CFrame.lookAt(pos,th.Position)if S.BTP_Smooth>=1 then C.CFrame=target else C.CFrame=C.CFrame:Lerp(target,S.BTP_Smooth)end end end end
local function BTP_Start()if S.BTP_Run==1 then return end if S.BTP_Target==""and S.BTP_Auto~=1 then return end S.BTP_Run=1 local m=BTP_HRP(LP)if m then btp.savedCF=m.CFrame end btp.savedCam=C.CameraType btp.savedSub=C.CameraSubject if btp.conn then btp.conn:Disconnect()end btp.conn=R.RenderStepped:Connect(function()if S.BTP_Run~=1 then return end pcall(BTP_Tick)end)end
local function BTP_Stop()S.BTP_Run=0 if btp.conn then btp.conn:Disconnect()btp.conn=nil end BTP_RestoreCam()BTP_Restore()end
local function BTP_PL()local n={}for _,p in ipairs(P:GetPlayers())do if p~=LP then table.insert(n,p.DisplayName.." (@"..p.Name..")")end end if#n==0 then table.insert(n,"(None)")end return n end

local CH={sg=nil,arms={},lab=nil,conn=nil,ang=0}
local function chParent()return(gethui and gethui())or LP:WaitForChild("PlayerGui")end
local function chDestroy()if CH.conn then pcall(function()CH.conn:Disconnect()end)CH.conn=nil end if CH.sg then pcall(function()CH.sg:Destroy()end)CH.sg=nil end CH.arms={}CH.lab=nil end
local function chMake()chDestroy()if S.CH~=1 then return end local sg=Instance.new("ScreenGui")sg.Name="UC_CH"sg.IgnoreGuiInset=true sg.ResetOnSpawn=false sg.DisplayOrder=9999 sg.Parent=chParent()CH.sg=sg
local root=Instance.new("Frame",sg)root.Name="Root"root.BackgroundTransparency=1 root.Size=UDim2.fromOffset(1,1)root.AnchorPoint=Vector2.new(.5,.5)root.Position=UDim2.fromScale(.5,.5)CH.root=root
local cols={Color3.fromRGB(0,255,120),Color3.fromRGB(0,200,255),Color3.fromRGB(180,80,255),Color3.fromRGB(255,60,160),Color3.fromRGB(255,220,40),Color3.fromRGB(255,80,80)}
for i=1,4 do local a=Instance.new("Frame",root)a.BorderSizePixel=0 a.AnchorPoint=Vector2.new(.5,.5)a.BackgroundColor3=cols[i]local c=Instance.new("UICorner",a)c.CornerRadius=UDim.new(1,0)local st=Instance.new("UIStroke",a)st.Thickness=1 st.Color=Color3.new(0,0,0)st.Transparency=.35 CH.arms[i]=a end
local lab=Instance.new("TextLabel",root)lab.BackgroundTransparency=1 lab.AnchorPoint=Vector2.new(.5,0)lab.Position=UDim2.new(.5,0,0,0)lab.Size=UDim2.fromOffset(80,16)lab.Font=Enum.Font.GothamBold lab.TextSize=11 lab.TextColor3=Color3.fromRGB(0,255,140)lab.TextStrokeTransparency=.4 lab.Text=""lab.Visible=false CH.lab=lab
CH.conn=R.RenderStepped:Connect(function(dt)
if S.CH~=1 or not CH.root then return end
local sz=S.CHSize or 28 local th=S.CHThick or 3 local gap=S.CHGap or 4 local armLen=sz
if S.CHSpin==1 then CH.ang=CH.ang+(S.CHSpeed or 2)*dt else CH.ang=math.rad(45)end
local hue=(tick()*0.35)%1
local function armCF(i)
local base=math.rad(45)+(i-1)*math.rad(90)+CH.ang
local ox=math.cos(base)*(gap+armLen*.5)local oy=math.sin(base)*(gap+armLen*.5)
return ox,oy,base
end
local col=Color3.fromHSV(hue,.9,1)
for i,a in ipairs(CH.arms)do
local ox,oy,base=armCF(i)
a.Size=UDim2.fromOffset(armLen,th)
a.Position=UDim2.fromOffset(ox,oy)
a.Rotation=math.deg(base)
a.BackgroundColor3=Color3.fromHSV((hue+(i-1)*.12)%1,.95,1)
end
CH.root.Position=UDim2.fromScale(.5,.5)
if CH.lab then CH.lab.Visible=false end
end)
end


local DN={on=1,sound=1,conns={}}
local function dnNotify(title,text)
pcall(function()if L and L.Notify then L:Notify({Title=title,Description=text,Time=4})end end)
pcall(function()game:GetService("StarterGui"):SetCore("SendNotification",{Title=title,Text=text,Duration=4})end)
end
local function dnPlay()
if DN.sound~=1 then return end
pcall(function()
local snd=Instance.new("Sound")
snd.SoundId="rbxassetid://97643101798871"
snd.Volume=.6
snd.Parent=game:GetService("SoundService")
snd:Play()
task.delay(2,function()pcall(function()snd:Destroy()end)end)
end)
end
local function dnHook(plr)
if plr==LP then return end
local function onChar(ch)
if not ch then return end
local h=ch:FindFirstChildOfClass("Humanoid")or ch:WaitForChild("Humanoid",5)
if not h then return end
local c
c=h.Died:Connect(function()
if DN.on~=1 then return end
if tm(plr)then return end -- skip teammates when team check on
local killer=""
pcall(function()
local t=h:FindFirstChild("creator")or h:FindFirstChild("Creator")
if t and t.Value then
local v=t.Value
if typeof(v)=="Instance"then
if v:IsA("Player")then killer=v.DisplayName
elseif v:IsA("Model")then local pp=P:GetPlayerFromCharacter(v)if pp then killer=pp.DisplayName end
end
end
end
end)
local msg=plr.DisplayName.." が倒された"
if killer~=""then msg=msg.." (by "..killer..")"end
dnNotify("死亡通知",msg)
dnPlay()
end)
table.insert(DN.conns,c)
end
if plr.Character then task.spawn(onChar,plr.Character)end
table.insert(DN.conns,plr.CharacterAdded:Connect(onChar))
end
local function dnStart()
for _,c in ipairs(DN.conns)do pcall(function()c:Disconnect()end)end DN.conns={}
for _,plr in ipairs(P:GetPlayers())do dnHook(plr)end
table.insert(DN.conns,P.PlayerAdded:Connect(dnHook))
end
local function dnStop()for _,c in ipairs(DN.conns)do pcall(function()c:Disconnect()end)end DN.conns={}end

local Win=L:CreateWindow({Title="Ultimate Cheat",Footer="Obsidian",NotifySide="Right",ShowCustomCursor=true})
local T={ESP=Win:AddTab("ESP","eye"),Aim=Win:AddTab("Aimbot","crosshair"),Plr=Win:AddTab("Player","user"),BTP=Win:AddTab("Back TP","move-vertical"),UI=Win:AddTab("UI","settings")}
local EG=T.ESP:AddLeftGroupbox("ESP")for _,k in ipairs({{"ESP","ESP 有効"},{"Box","Box"},{"Name","Name"},{"HP","HP"},{"Dist","Dist"},{"Team","Team Check (最大強化)"}})do EG:AddToggle(k[1],{Text=k[2],Default=S[k[1]]==1,Callback=function(v)S[k[1]]=v and 1 or 0 er()end})end
T.ESP:AddRightGroupbox("Settings"):AddSlider("MaxDist",{Text="Max Dist",Default=S.MaxDist,Min=100,Max=3000,Callback=function(v)S.MaxDist=v end})

local ED=T.ESP:AddRightGroupbox("Death Notify")
ED:AddToggle("DN",{Text="死亡通知",Default=true,Callback=function(v)DN.on=v and 1 or 0 if v then dnStart()else dnStop()end end})
ED:AddToggle("DNSound",{Text="死亡通知サウンド",Default=true,Callback=function(v)DN.sound=v and 1 or 0 end})
local AG=T.Aim:AddLeftGroupbox("Aimbot")for _,k in ipairs({{"Aim","Aimbot 有効"},{"Sticky","Sticky"},{"BodyLock","Body Lock"},{"Wall","Wall Check"}})do AG:AddToggle(k[1],{Text=k[2],Default=S[k[1]]==1,Callback=function(v)S[k[1]]=v and 1 or 0 if k[1]=="Aim"then lk=nil end end})end
AG:AddSlider("FOV",{Text="FOV",Default=S.FOV,Min=10,Max=800,Callback=function(v)S.FOV=v end})AG:AddSlider("Smooth",{Text="Smooth",Default=S.Smooth,Min=.01,Max=1,Rounding=2,Callback=function(v)S.Smooth=v end})AG:AddSlider("Curve",{Text="Curve",Default=S.Curve,Min=1,Max=10,Rounding=1,Callback=function(v)S.Curve=v end})
T.Aim:AddRightGroupbox("Target"):AddDropdown("Part",{Text="Part",Values={"Head","HumanoidRootPart","UpperTorso","Torso"},Default=S.Part,Callback=function(v)S.Part=v end})

local CGH=T.Aim:AddRightGroupbox("Crosshair")
CGH:AddToggle("CH",{Text="クロスヘア",Default=S.CH==1,Callback=function(v)S.CH=v and 1 or 0 if v then chMake()else chDestroy()end end})
CGH:AddToggle("CHSpin",{Text="回転",Default=S.CHSpin==1,Callback=function(v)S.CHSpin=v and 1 or 0 end})
CGH:AddToggle("CHFollow",{Text="エイム対象に追従(OFF=中央固定)",Default=false,Callback=function(v)S.CHFollow=v and 1 or 0 end})
CGH:AddSlider("CHSize",{Text="大きさ",Default=S.CHSize,Min=8,Max=80,Rounding=0,Callback=function(v)S.CHSize=v end})
CGH:AddSlider("CHThick",{Text="太さ",Default=S.CHThick,Min=1,Max=12,Rounding=0,Callback=function(v)S.CHThick=v end})
CGH:AddSlider("CHGap",{Text="隙間",Default=S.CHGap,Min=0,Max=20,Rounding=0,Callback=function(v)S.CHGap=v end})
CGH:AddSlider("CHSpeed",{Text="回転速度",Default=S.CHSpeed,Min=.2,Max=8,Rounding=1,Callback=function(v)S.CHSpeed=v end})
local PG=T.Plr:AddLeftGroupbox("Player")PG:AddToggle("Noclip",{Text="Noclip",Default=S.Noclip==1,Callback=function(v)nc_(v)end})PG:AddToggle("InfJump",{Text="Inf Jump",Default=S.InfJump==1,Callback=function(v)ij(v)end})PG:AddToggle("AntiDie",{Text="Anti-Die",Default=S.AntiDie==1,Callback=function(v)if v then adStart()else adStop()end end})
local SG=T.Plr:AddRightGroupbox("Speed Up")SG:AddToggle("Speed",{Text="Speed Up",Default=S.Speed==1,Callback=function(v)spt(v)end})SG:AddSlider("SpeedVal",{Text="WalkSpeed",Default=S.SpeedVal,Min=16,Max=500,Callback=function(v)S.SpeedVal=v if S.Speed==1 then spa()end end})SG:AddSlider("Jump",{Text="JumpPower",Default=S.JumpPower,Min=50,Max=500,Callback=function(v)S.JumpPower=v if S.Speed==1 then spa()end end})
local BG1=T.BTP:AddLeftGroupbox("対象","target")BG1:AddDropdown("BTP_TD",{Text="対象",Values=BTP_PL(),Default="",Callback=function(v)S.BTP_Target=(v and v:match("@(.+)%)"))or""end})BG1:AddButton({Text="🔄 更新",Func=function()pcall(function()L.Options.BTP_TD:SetValues(BTP_PL())end)end})BG1:AddToggle("BTP_Auto",{Text="一番近い敵を自動選択",Default=false,Callback=function(v)S.BTP_Auto=v and 1 or 0 end})
local BG2=T.BTP:AddLeftGroupbox("実行","user")BG2:AddToggle("BTP_Run",{Text="★ 背中TP + 視線固定",Default=false,Risky=true,Callback=function(v)if v then BTP_Start()else BTP_Stop()end end})BG2:AddButton({Text="🛑 停止",Func=BTP_Stop})BG2:AddButton({Text="▶ 1回実行",Func=function()pcall(BTP_Tick)end})BG2:AddLabel("OFFにすると元の位置に戻ります")
local BG3=T.BTP:AddRightGroupbox("復元","settings")BG3:AddToggle("BTP_Restore",{Text="停止時に元の位置に戻る",Default=true,Callback=function(v)S.BTP_Restore=v and 1 or 0 end})BG3:AddButton({Text="📍 現在位置を保存",Func=function()local m=BTP_HRP(LP)if m then btp.savedCF=m.CFrame end end})BG3:AddButton({Text="▶ 保存位置に戻る",Func=BTP_Restore})
local BSG1=T.BTP:AddLeftGroupbox("TP設定","settings")BSG1:AddToggle("BTP_TPOn",{Text="テレポート有効",Default=true,Callback=function(v)S.BTP_TPOn=v and 1 or 0 end})BSG1:AddSlider("BTP_Dist",{Text="TP距離",Default=.5,Min=.5,Max=20,Rounding=1,Suffix=" stud",Callback=function(v)S.BTP_Dist=v end})BSG1:AddSlider("BTP_Height",{Text="TP高さ",Default=10,Min=-5,Max=10,Rounding=1,Suffix=" stud",Callback=function(v)S.BTP_Height=v end})BSG1:AddSlider("BTP_Int",{Text="TP更新間隔",Default=.001,Min=.001,Max=1,Rounding=3,Suffix="s",Callback=function(v)S.BTP_Int=v end})
local BSG2=T.BTP:AddRightGroupbox("カメラ設定","settings")BSG2:AddToggle("BTP_LockOn",{Text="視線固定有効",Default=true,Callback=function(v)S.BTP_LockOn=v and 1 or 0 end})BSG2:AddSlider("BTP_CamDist",{Text="カメラの背中距離",Default=5,Min=1,Max=30,Rounding=1,Suffix=" stud",Callback=function(v)S.BTP_CamDist=v end})BSG2:AddSlider("BTP_CamHeight",{Text="カメラの高さ",Default=2,Min=-5,Max=15,Rounding=1,Suffix=" stud",Callback=function(v)S.BTP_CamHeight=v end})BSG2:AddSlider("BTP_Smooth",{Text="スムーズさ (0.05〜1)",Default=.15,Min=.03,Max=1,Rounding=2,Callback=function(v)S.BTP_Smooth=v end})
P.PlayerAdded:Connect(function(p)p.CharacterAdded:Connect(function()task.wait(.35)if S.ESP==1 then em(p)end end)end)P.PlayerRemoving:Connect(ec)R.RenderStepped:Connect(lp)
LP.CharacterAdded:Connect(function(c)task.wait(.5)local h=H(c)if h then orig=h.AutoRotate if S.Aim==1 and S.BodyLock==1 then h.AutoRotate=false end end if S.Speed==1 then sps()spa()end end)
if TM then pcall(function()TM:SetLibrary(L)TM:SetFolder("UltimateCheat")TM:ApplyToTab(T.UI)end)end
if SM then pcall(function()SM:SetLibrary(L)SM:IgnoreThemeSettings()SM:SetIgnoreIndexes({"MenuKeybind"})SM:SetFolder("UltimateCheat")SM:BuildConfigSection(T.UI)end)end
local function clr()S.ESP=0 S.Aim=0 S.Noclip=0 S.InfJump=0 S.Speed=0 adStop()if nc then pcall(function()nc:Disconnect()end)end if ic then pcall(function()ic:Disconnect()end)end spc()er()pcall(BTP_Stop)pcall(chDestroy)pcall(dnStop)local h=H(LP.Character)if h then pcall(function()h.AutoRotate=orig h.WalkSpeed=16 h.JumpPower=50 end)end end
if L.OnUnload then pcall(function()L:OnUnload(clr)end)end if L.Unload and L.Unload.Connect then pcall(function()L.Unload:Connect(clr)end)end
if LP.Character then local h=H(LP.Character)if h then orig=h.AutoRotate end end
nc_(1)ij(1)spt(1)er()if S.AntiDie==1 then adStart()end
if S.CH==1 then chMake()end
dnStart()
do local CG=T.UI:AddLeftGroupbox("Theme Colors")local function ap(k,c)if L.Scheme and L.Scheme[k]~=nil then L.Scheme[k]=c end if L.UpdateColorsUsingRegistry then pcall(function()L:UpdateColorsUsingRegistry()end)end end local function dc(n,fb)if L.Scheme and L.Scheme[n]then return L.Scheme[n]end return fb end
CG:AddColorPicker("MainColor",{Text="Main",Default=dc("MainColor",Color3.fromRGB(25,25,25)),Callback=function(c)ap("MainColor",c)end})CG:AddColorPicker("AccentColor",{Text="Accent",Default=dc("AccentColor",Color3.fromRGB(125,85,255)),Callback=function(c)ap("AccentColor",c)end})CG:AddColorPicker("BackgroundColor",{Text="Background",Default=dc("BackgroundColor",Color3.fromRGB(15,15,15)),Callback=function(c)ap("BackgroundColor",c)end})CG:AddColorPicker("OutlineColor",{Text="Outline",Default=dc("OutlineColor",Color3.fromRGB(40,40,40)),Callback=function(c)ap("OutlineColor",c)end})CG:AddColorPicker("FontColor",{Text="Font",Default=dc("FontColor",Color3.new(1,1,1)),Callback=function(c)ap("FontColor",c)end})end
