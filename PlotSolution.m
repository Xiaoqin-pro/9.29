function PlotSolution(BestSol,model,state,filePath)
    % 两参数时绘制对比结果：PlotSolution(runs,out)。
    if nargin==2
        PlotComparison(BestSol,model);
        return;
    end
    % 在原始地形坐标和原图风格上叠加威胁区、配送点和三维路径。
    % 原地形数据不变，不做垂直夸张。额外输出_debug站点编号图。
    detail = BestSol.Detail;
    [folder,name,ext] = fileparts(filePath);
    if ~exist(folder,'dir')
        mkdir(folder);
    end
    for debug = [false true]
        f = figure('Color','w','Position',[100 100 1200 820]);
        ax = axes(f,'Position',[0.08 0.14 0.73 0.77]);
        ax.Toolbar.Visible='off';
        hold(ax,'on');
        surf(ax,model.X,model.Y,model.terrainZ,model.terrainZ, ...
            'EdgeColor','none','FaceColor','flat','FaceAlpha',1, ...
            'FaceLighting','none','DisplayName','Terrain');
        colormap(ax,parula(256));
        clim(ax,[0 max(model.terrainZ(:))]);
        cb = colorbar(ax,'Position',[0.86 0.24 0.017 0.53]);
        cb.Label.String = 'Terrain height (model units)';
        %% 三维圆柱威胁区：侧面、顶面和边界，地形保持原样
        displayHeightScale=1.35;
        for i=1:numel(model.obstacles)
            obs=model.obstacles(i);
            [X,Y,Z]=cylinder(obs.r,64);
            X=X+obs.x;
            Y=Y+obs.y;
            displayTop=obs.zMin+displayHeightScale*(obs.zMax-obs.zMin);
            Z=obs.zMin+Z*(displayTop-obs.zMin);
            h=surf(ax,X,Y,Z,'FaceColor',[0.88 0.18 0.16], ...
                'FaceAlpha',0.20,'EdgeColor','none','FaceLighting','none');
            if i==1
                h.DisplayName='Cylindrical threat';
            else
                h.HandleVisibility='off';
            end
            patch(ax,X(2,:),Y(2,:),Z(2,:),[0.88 0.18 0.16], ...
                'FaceAlpha',0.14,'EdgeColor',[0.75 0.12 0.1], ...
                'LineWidth',1,'HandleVisibility','off');
            plot3(ax,X(1,:),Y(1,:),Z(1,:),'Color',[0.75 0.12 0.1], ...
                'LineWidth',0.8,'HandleVisibility','off');
            if debug
                theta=linspace(0,2*pi,100);
                radius=obs.r+model.obstacleSafety;
                xx=obs.x+radius*cos(theta);
                yy=obs.y+radius*sin(theta);
                zz=interp2(model.X,model.Y,model.terrainZ,xx,yy)+0.2;
                plot3(ax,xx,yy,zz,'--','Color',[0.86 0.28 0.25], ...
                    'LineWidth',0.8,'HandleVisibility','off');
                text(ax,obs.x,obs.y,displayTop+0.6,sprintf('T%d',obs.id), ...
                'Color',[0.75 0.05 0.05],'FontSize',10,'FontWeight','bold');
            end
        end
        p=detail.points;
        plot3(ax,p(:,1),p(:,2),p(:,3),'-','Color',[0.05 0.16 0.65], ...
            'LineWidth',2.3,'DisplayName','Delivery route');
        xyz=reshape([model.orders(state.activeIDs).xyz],3,[])';
        scatter3(ax,xyz(:,1),xyz(:,2),xyz(:,3),44,[1 0.78 0.12], ...
            'filled','MarkerEdgeColor',[0.15 0.15 0.15],'DisplayName','Delivery stations');
        plot3(ax,model.depot(1),model.depot(2),model.depot(3),'s','Color','k', ...
            'MarkerSize',10,'MarkerFaceColor','w','LineWidth',1.5,'DisplayName','Depot');
        if debug
            for id=state.activeIDs(:)'
                p=model.orders(id).xyz;
                text(ax,p(1)+1,p(2)+1,p(3)+0.4,sprintf('S%d',model.orders(id).stationID), ...
                'FontSize',9,'BackgroundColor','w','Margin',0.3);
            end
            for i=1:numel(detail.paths)
                p=detail.paths{i}.points(2:end-1,:);
                plot3(ax,p(:,1),p(:,2),p(:,3),'o','MarkerSize',3, ...
                    'Color',[0.05 0.16 0.65],'MarkerFaceColor','w','HandleVisibility','off');
            end
        end
        xlabel(ax,'X (model units)');
        ylabel(ax,'Y (model units)');
        zlabel(ax,'Z (model units)');
        xlim(ax,[0 model.mapSize(1)]);
        ylim(ax,[0 model.mapSize(2)]);
        zlim(ax,[0 max([22;detail.points(:,3);[model.obstacles.zMax]'])+1]);
        view(ax,40,35);
        daspect(ax,[1 1 1]);
        grid(ax,'on');
        box(ax,'on');
        set(ax,'FontName','Arial','FontSize',11,'GridAlpha',0.16,'Projection','orthographic');
        status='Feasible';
        if ~detail.feasible
            status='Infeasible candidate';
        end
        heading=[model.terrainName ' | ' BestSol.Algorithm ' | 3-D delivery with threat zones'];
        title(ax,{heading, ...
            sprintf('%s | Late %.2f | Return %.2f / %.2f',status,detail.totalLate,detail.finishTime,model.depotDue)}, ...
        'FontWeight','normal','FontSize',13);
        legend(ax,'Location','southoutside','Orientation','horizontal','Box','off','FontSize',10);
        annotation(f,'textbox',[0.1 0.005 0.83 0.04],'String', ...
            'Original terrain scale. Red cylinders: 3-D threats; dashed circles: safety margin.', ...
            'EdgeColor','none','HorizontalAlignment','center','FontSize',9);
        target=fullfile(folder,[name ext]);
        if debug
            target=fullfile(folder,[name '_debug' ext]);
        end
        exportgraphics(f,target,'Resolution',250);
    end
    PlotTimeWindows(detail,model,fullfile(folder,[strrep(name,'_route_3D','') '_time_windows.png']));
end

function PlotTimeWindows(detail,model,filePath)
    schedule = array2table(detail.records,'VariableNames',detail.scheduleColumns);
    % 到达、等待、服务与硬时间窗。
    figure('Color','w','Position',[100 100 1100 760]);
    hold on
    for k = 1:height(schedule)
        a = plot([schedule.Ready(k) schedule.Due(k)],[k k], ...
            'Color',[0.80 0.84 0.89],'LineWidth',8);
        b = plot([schedule.Arrival(k) schedule.ServiceStart(k)],[k k], ...
            'Color',[0.95 0.63 0.16],'LineWidth',4);
        c = plot([schedule.ServiceStart(k) schedule.Departure(k)],[k k], ...
            'Color',[0.15 0.60 0.42],'LineWidth',7);
        d = plot(schedule.Arrival(k),k,'o','Color',[0.04 0.25 0.78], ...
            'MarkerFaceColor','w','MarkerSize',5);
    end
    set(gca,'YTick',1:height(schedule),'YTickLabel', ...
        compose('S%d',schedule.ID),'YDir','reverse','FontSize',11);
    ylim([0.5 height(schedule)+0.5]);
    ax = gca;
    ax.Toolbar.Visible = 'off';
    xlabel('Time (model time units)');
    ylabel('Delivery order');
    title(sprintf('%s | Delivery time windows | Return %.2f / %.2f', ...
    model.terrainName,detail.finishTime,model.depotDue));
    legend([a b c d],{'Time window','Waiting','Service','Arrival'}, ...
        'Location','southoutside','Orientation','horizontal');
    grid on;
    box on;
    exportgraphics(gcf,filePath,'Resolution',200);

end

function PlotComparison(runs,out)
    algorithms=cellstr(unique(string(runs.Algorithm),'stable'))';
    maps=unique(string(runs.Terrain),'stable');
    cases=unique(string(runs.Scenario),'stable');
    colors=lines(numel(algorithms));
    % 各算法可行率单独呈现，不将罚项Cost误作可行解质量。
    for map=maps'
        rates=zeros(length(cases),numel(algorithms));
        for number=1:length(cases)
            for k=1:numel(algorithms)
                selected=string(runs.Terrain)==map & string(runs.Scenario)==cases(number) ...
                    & string(runs.Algorithm)==algorithms{k};
                rates(number,k)=mean(runs.Feasible(selected));
            end
        end
        f=figure('Visible','off','Color','w','Position',[100 100 1100 650]);
        hold on;
        for k=1:numel(algorithms)
            offset=.8*(k-(numel(algorithms)+1)/2)/numel(algorithms);
            bar((1:length(cases))+offset,rates(:,k),.8/numel(algorithms), ...
                'FaceColor',colors(k,:),'DisplayName',algorithms{k});
        end
        xlim([.5 length(cases)+.5]);ylim([0 1]);grid on;
        xticks(1:length(cases));xticklabels(strrep(cases,'_',' '));
        ylabel('Feasible rate');title([char(map) ' | Feasibility under equal evaluation budgets']);
        legend(algorithms,'Location','southoutside','Orientation','horizontal');
        exportgraphics(f,fullfile(out,[char(map) '_feasible_rate.png']),'Resolution',180);
        close(f);
    end

    for map=maps'
        f=figure('Visible','off','Color','w','Position',[100 100 1400 850]);
        layout=tiledlayout(f,2,3,'Padding','compact','TileSpacing','compact');
        title(layout,sprintf('%s | Mean convergence (equal evaluation budget)',map));
        for number=1:length(cases)
            ax=nexttile(layout);
            hold(ax,'on');
            scenario=cases(number);
            for k=1:numel(algorithms)
                selected=string(runs.Terrain)==map & string(runs.Scenario)==scenario & string(runs.Algorithm)==algorithms{k};
                group=runs(selected,:);
                if isempty(group)
                    continue;
                end
                histories=zeros(group.Evaluations(1),height(group));
                for r=1:height(group)
                    value=load(fullfile(out,group.File{r}),'T');
                    histories(:,r)=value.T;
                end
                first=load(fullfile(out,group.File{1}),'info');
                N=size(first.info.InitialPopulation,1);
                plot(ax,N:size(histories,1),mean(histories(N:end,:),2),'Color',colors(k,:),'LineWidth',1.6,'DisplayName',algorithms{k});
            end
            title(ax,strrep(char(scenario),'_',' '));
            xlabel(ax,'Fitness evaluations');
            ylabel(ax,'Best objective');
            grid(ax,'on');
            box(ax,'on');
            ax.Toolbar.Visible='off';
            legend(ax,'Location','best','FontSize',8);
        end
        exportgraphics(f,fullfile(out,[char(map) '_convergence.png']),'Resolution',200);
        exportgraphics(f,fullfile(out,[char(map) '_convergence.pdf']),'ContentType','vector');
        close(f);
        f=figure('Visible','off','Color','w','Position',[100 100 1400 850]);
        layout=tiledlayout(f,2,3,'Padding','compact','TileSpacing','compact');
        title(layout,sprintf('%s | Repeated-run objective (feasible solutions)',map));
        for number=1:length(cases)
            ax=nexttile(layout);
            x=[];
            y=[];
            for k=1:numel(algorithms)
                selected=string(runs.Terrain)==map & string(runs.Scenario)==cases(number) ...
                    & string(runs.Algorithm)==algorithms{k} & runs.Feasible;
                y=[y;runs.Cost(selected)];
                x=[x;k*ones(sum(selected),1)];
            end
            if isempty(y)
                text(ax,0.5,0.5,'No feasible solutions','HorizontalAlignment','center');
            else
                boxchart(ax,x,y,'BoxFaceColor',[0.2 0.5 0.75]);
            end
            xlim(ax,[0.5 numel(algorithms)+.5]);
            xticks(ax,1:numel(algorithms));
            xticklabels(ax,algorithms);
            title(ax,strrep(char(cases(number)),'_',' '));
            ylabel(ax,'Objective');
            grid(ax,'on');
            ax.Toolbar.Visible='off';
        end
        exportgraphics(f,fullfile(out,[char(map) '_boxplot.png']),'Resolution',200);
        exportgraphics(f,fullfile(out,[char(map) '_boxplot.pdf']),'ContentType','vector');
        close(f);
        % 最后一组场景：每种算法展示最佳可行结果并保留运行来源。
        routeDir=fullfile(out,'routes',char(map));
        if ~exist(routeDir,'dir')
            mkdir(routeDir);
        end
        for k=1:numel(algorithms)
            selected=string(runs.Terrain)==map & string(runs.Scenario)==cases(end) ...
                & string(runs.Algorithm)==algorithms{k} & runs.Feasible;
            group=runs(selected,:);
            if isempty(group)
                continue;
            end
            [~,index]=min(group.Cost);
            d=load(fullfile(out,group.File{index}),'Best','model','state');
            d.Best.Algorithm=algorithms{k};
            PlotSolution(d.Best,d.model,d.state,fullfile(routeDir,[algorithms{k} '.png']));
            close all;
            writetable(array2table(d.Best.Detail.records,'VariableNames',d.Best.Detail.scheduleColumns), ...
                fullfile(routeDir,[algorithms{k} '_schedule.csv']));
            source=group(index,:);
            writetable(source,fullfile(routeDir,[algorithms{k} '_source.csv']));
        end
    end

end
